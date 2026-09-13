#!/usr/bin/env python3
"""Build and exercise the packaged owner policy in an isolated local Keycloak."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=18084)
    parser.add_argument("--name", default="keycloak-owner-policy-demo")
    args = parser.parse_args()
    image = args.name + ":26.5.7"
    source = Path(__file__).resolve().parent
    base = f"http://localhost:{args.port}"
    admin_token = None

    def docker(*arguments, **kwargs):
        return subprocess.run(["docker", *arguments], check=True, **kwargs)

    def request(method, path, data=None, form=None, token=None):
        headers = {}
        body = None
        if token:
            headers["Authorization"] = "Bearer " + token
        if data is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(data).encode()
        if form is not None:
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            body = urllib.parse.urlencode(form).encode()
        req = urllib.request.Request(base + path, data=body, headers=headers, method=method)
        try:
            response = urllib.request.urlopen(req, timeout=10)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            text = response.read().decode()
            result = json.loads(text) if text else None
            return response.status, result

    def api(method, path, data=None):
        status, result = request(method, "/admin/realms" + path, data=data, token=admin_token)
        if not 200 <= status < 300:
            raise RuntimeError(f"{method} {path}: HTTP {status}: {result}")
        return result

    # Refuse collisions before creating anything; cleanup only owns newly created resources.
    for resource, value in [("container", args.name), ("image", image)]:
        exists = subprocess.run(
            ["docker", resource, "inspect", value],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
        )
        if exists.returncode == 0:
            raise RuntimeError(f"{resource} {value} exists; choose a different --name")
    container_created = False
    image_created = False
    try:
        with tempfile.TemporaryDirectory(prefix="keycloak-owner-policy-") as temporary:
            build = Path(temporary)
            with zipfile.ZipFile(build / "owner-policies.jar", "w") as jar:
                for name in ["owner-delete.js", "META-INF/keycloak-scripts.json"]:
                    jar.write(source / name, name)
            shutil.copyfile(source / "Dockerfile", build / "Dockerfile")
            docker("build", "--tag", image, str(build))
            image_created = True
        docker(
            "create", "--name", args.name, "--publish", f"127.0.0.1:{args.port}:8080",
            "--env", "KC_BOOTSTRAP_ADMIN_USERNAME=admin",
            "--env", "KC_BOOTSTRAP_ADMIN_PASSWORD=admin", image,
        )
        container_created = True
        docker("start", args.name)
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            try:
                status, tokens = request("POST", "/realms/master/protocol/openid-connect/token", form={
                    "grant_type": "password", "client_id": "admin-cli",
                    "username": "admin", "password": "admin",
                })
                if status == 200:
                    admin_token = tokens["access_token"]
                    break
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                pass
            time.sleep(1)
        else:
            raise RuntimeError("Keycloak did not become ready within 180 seconds")

        realm = "/owner-policy-demo"
        api("POST", "", {"realm": realm[1:], "enabled": True})
        users = {}
        for username in ["owner", "nonowner"]:
            api("POST", realm + "/users", {
                "username": username, "enabled": True, "firstName": username,
                "lastName": "Demo", "email": username + "@example.test", "emailVerified": True,
                "credentials": [{"type": "password", "value": "Muster1234!", "temporary": False}],
            })
            users[username] = api("GET", realm + "/users?username=" + username + "&exact=true")[0]["id"]
        api("POST", realm + "/clients", {
            "clientId": "documents", "publicClient": False, "secret": "local-demo-secret",
            "standardFlowEnabled": True, "serviceAccountsEnabled": True,
            "authorizationServicesEnabled": True, "directAccessGrantsEnabled": True,
        })
        client = api("GET", realm + "/clients?clientId=documents")[0]["id"]
        authz = realm + "/clients/" + client + "/authz/resource-server"
        providers = api("GET", authz + "/policy/providers")
        provider = next(p for p in providers if p["name"] == "Owner delete")
        # Auto-created defaults must not grant access independently of the owner predicate.
        for kind in ["permission", "policy"]:
            for item in api("GET", authz + "/" + kind):
                api("DELETE", authz + "/" + kind + "/" + item["id"])
        scope = api("POST", authz + "/scope", {"name": "delete"})["id"]
        resource = api("POST", authz + "/resource", {
            "name": "document-1", "owner": {"id": users["owner"]},
            "scopes": [{"id": scope, "name": "delete"}],
        })["_id"]
        policy = api("POST", authz + "/policy/" + provider["type"], {
            "name": "Only owner deletes", "type": provider["type"], "logic": "POSITIVE",
        })["id"]
        api("POST", authz + "/permission/scope", {
            "name": "Delete document", "type": "scope", "decisionStrategy": "UNANIMOUS",
            "resources": [resource], "scopes": [scope], "policies": [policy],
        })
        results = {}
        for username, expected in [("owner", "PERMIT"), ("nonowner", "DENY")]:
            evaluation = api("POST", authz + "/policy/evaluate", {
                "clientId": client, "userId": users[username],
                "resources": [{"_id": resource, "scopes": [{"id": scope, "name": "delete"}]}],
            })
            status, tokens = request("POST", "/realms" + realm + "/protocol/openid-connect/token", form={
                "grant_type": "password", "client_id": "documents", "client_secret": "local-demo-secret",
                "username": username, "password": "Muster1234!",
            })
            if status != 200:
                raise RuntimeError(f"User token failed: {status}: {tokens}")
            status, decision = request("POST", "/realms" + realm + "/protocol/openid-connect/token", form={
                "grant_type": "urn:ietf:params:oauth:grant-type:uma-ticket", "audience": "documents",
                "permission": resource + "#delete", "response_mode": "decision",
            }, token=tokens["access_token"])
            if evaluation["status"] != expected:
                raise RuntimeError(f"Unexpected evaluation for {username}: {evaluation}")
            if username == "owner" and (status != 200 or decision.get("result") is not True):
                raise RuntimeError(f"Owner denied: {status}: {decision}")
            if username == "nonowner" and (status != 403 or decision.get("error") != "access_denied"):
                raise RuntimeError(f"Non-owner allowed: {status}: {decision}")
            results[username] = {"evaluation": evaluation["status"], "umaStatus": status, "umaBody": decision}
        print(json.dumps(results, indent=2), flush=True)
    finally:
        cleanup = []
        if container_created:
            cleanup.extend([("logs", args.name), ("stop", args.name), ("rm", args.name)])
        if image_created:
            cleanup.append(("image", "rm", image))
        failed_cleanup = []
        for arguments in cleanup:
            result = subprocess.run(["docker", *arguments], check=False)
            if result.returncode:
                failed_cleanup.append("docker " + " ".join(arguments))
        if failed_cleanup:
            message = "Cleanup failed: " + "; ".join(failed_cleanup)
            print(message, file=sys.stderr)
            if sys.exc_info()[0] is None:
                raise RuntimeError(message)


if __name__ == "__main__":
    main()
