import json
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import lab


class TokenHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers['Content-Length']))
        self.send_response(401)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'error': 'invalid_client'}).encode())

    def log_message(self, *args):
        pass


class LabTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        lab.STATE = Path(self.temp.name)

    def test_labels_cannot_escape_state_directory(self):
        for label in ['../other', '/tmp/token', 'a/b', '', 'a.b']:
            with self.subTest(label=label), self.assertRaises(ValueError):
                lab.state_file(label, 'token')

    def test_valid_label_remains_in_state_directory(self):
        self.assertEqual(lab.state_file('key-before', 'token'), lab.STATE / 'key-before.token')

    def token_server(self):
        server = HTTPServer(('127.0.0.1', 0), TokenHandler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        lab.KEYCLOAK = f'http://127.0.0.1:{server.server_port}'
        (lab.STATE / 'old.secret').write_text('invalid-demo-secret')
        (lab.STATE / 'before.token').write_text('stale-token')

    def test_failed_token_request_cannot_leave_stale_token(self):
        self.token_server()
        lab.fetch_token('old', 'before', expected=401)
        self.assertFalse((lab.STATE / 'before.token').exists())

    def test_unexpected_status_fails_the_check(self):
        self.token_server()
        with self.assertRaises(RuntimeError):
            lab.fetch_token('old', 'before', expected=200)
        self.assertFalse((lab.STATE / 'before.token').exists())


if __name__ == '__main__':
    unittest.main()
