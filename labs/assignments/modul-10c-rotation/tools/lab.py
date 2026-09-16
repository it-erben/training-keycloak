"""Small HTTP client for the local Keycloak rotation exercise."""
import argparse
import base64
import getpass
import json
import os
from pathlib import Path
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

STATE = Path(os.environ.get('LAB_STATE_DIR', '/state'))
KEYCLOAK = os.environ.get('KEYCLOAK_URL', 'http://keycloak:8080')
API = os.environ.get('API_URL', 'http://api:3001')
REALM = '/realms/mustertech/protocol/openid-connect'


def state_file(name, kind):
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', name):
        raise ValueError('Namen dürfen nur Buchstaben, Ziffern, _ und - enthalten.')
    return STATE / f'{name}.{kind}'


def save(path, value):
    STATE.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding='utf-8')
    path.chmod(0o600)


def request(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    try:
        response = urllib.request.urlopen(req, timeout=15)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, json.load(response)


def check_status(status, expected, data):
    print(f'HTTP {status}' + (f" ({data['error']})" if 'error' in data else ''))
    if status != expected:
        raise RuntimeError(f'Erwartet war HTTP {expected}.')


def fetch_token(secret_name, token_name, expected=200):
    target = state_file(token_name, 'token')
    # Never let a failed retry look successful by retaining an earlier token.
    target.unlink(missing_ok=True)
    secret = state_file(secret_name, 'secret').read_text().strip()
    body = urllib.parse.urlencode({
        'grant_type': 'client_credentials', 'client_id': 'sync-service',
        'client_secret': secret,
    }).encode()
    status, data = request(KEYCLOAK + REALM + '/token', body)
    check_status(status, expected, data)
    if status == 200:
        save(target, data['access_token'])
        inspect_token(token_name)


def inspect_token(name):
    token = state_file(name, 'token').read_text().strip()
    header, payload, _ = token.split('.')
    decode = lambda part: json.loads(base64.urlsafe_b64decode(part + '=' * (-len(part) % 4)))
    head, claims = decode(header), decode(payload)
    print(json.dumps({
        'Datei': name, 'alg': head.get('alg'), 'kid': head.get('kid'),
        'iss': claims.get('iss'), 'azp': claims.get('azp'),
        'Restlaufzeit_Sekunden': int(claims['exp'] - time.time()),
    }, ensure_ascii=False, indent=2))
    print('Nur dekodiert. Die Signaturprüfung übernimmt der API-Aufruf.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for command in ['secret', 'inspect']:
        commands.add_parser(command).add_argument('name')
    token = commands.add_parser('token')
    token.add_argument('secret')
    token.add_argument('name')
    token.add_argument('--expect', type=int, default=200)
    api = commands.add_parser('api')
    api.add_argument('name')
    api.add_argument('--expect', type=int, default=200)
    commands.add_parser('jwks')
    args = parser.parse_args()
    if args.command == 'secret':
        path = state_file(args.name, 'secret')
        secret = getpass.getpass('Client-Secret einfügen (Eingabe unsichtbar): ').strip()
        if not secret:
            raise ValueError('Das Secret darf nicht leer sein.')
        save(path, secret)
        print(f'Secret unter {args.name} gespeichert.')
    elif args.command == 'token':
        fetch_token(args.secret, args.name, args.expect)
    elif args.command == 'inspect':
        inspect_token(args.name)
    elif args.command == 'jwks':
        status, data = request(KEYCLOAK + REALM + '/certs')
        check_status(status, 200, data)
        print(json.dumps([{k: key.get(k) for k in ['kid', 'alg', 'use']}
                          for key in data['keys']], indent=2))
    elif args.command == 'api':
        token = state_file(args.name, 'token').read_text().strip()
        status, data = request(API + '/api/profile', headers={'Authorization': 'Bearer ' + token})
        check_status(status, args.expect, data)
        if status == 200:
            print('API-Benutzer:', data.get('username'))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(f'Prüfung fehlgeschlagen: {error}', file=sys.stderr)
        sys.exit(1)
