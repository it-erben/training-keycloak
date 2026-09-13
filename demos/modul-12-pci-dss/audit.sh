#!/usr/bin/env bash
# Prüft den Realm mustertech des Lab-Stacks gegen PCI-DSS-Grenzwerte.
# Liest über kcadm.sh im Container assignment-keycloak; braucht python3 auf dem Host.
set -euo pipefail

CONTAINER="${CONTAINER:-assignment-keycloak}"
REALM="${REALM:-mustertech}"
# KEYCLOAK_URL is reachable from the host; KCADM_SERVER from inside the container.
export KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
export ADMIN_USER="${ADMIN_USER:-admin}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
KCADM_SERVER="${KCADM_SERVER:-http://localhost:8080}"
token_only=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --otp)
      printf 'Aktueller OTP-Code: ' >&2
      IFS= read -r -s ADMIN_OTP || { printf '\nOTP-Eingabe fehlt.\n' >&2; exit 2; }
      printf '\n' >&2
      [ -n "$ADMIN_OTP" ] || { printf 'OTP-Eingabe ist leer.\n' >&2; exit 2; }
      export ADMIN_OTP
      ;;
    --token) token_only=true ;;
    *) printf 'Aufruf: %s [--otp] [--token]\n' "$0" >&2; exit 2 ;;
  esac
  shift
done

# Request a fresh token, including OTP when supplied; never reuse kcadm's cached login.
TOKEN=$(python3 - <<'PYTHON'
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

form = dict(grant_type="password", client_id="admin-cli",
            username=os.environ["ADMIN_USER"], password=os.environ["ADMIN_PASSWORD"])
if os.environ.get("ADMIN_OTP"):
    form["totp"] = os.environ["ADMIN_OTP"]
url = os.environ["KEYCLOAK_URL"].rstrip("/") + "/realms/master/protocol/openid-connect/token"
try:
    with urllib.request.urlopen(url, data=urllib.parse.urlencode(form).encode(), timeout=15) as response:
        print(json.load(response)["access_token"])
except urllib.error.HTTPError as error:
    print(f"Admin-Anmeldung fehlgeschlagen (HTTP {error.code}). "
          "Zugangsdaten prüfen; nach OTP-Einrichtung --otp mit einem frischen Code verwenden.", file=sys.stderr)
    sys.exit(2)
except (urllib.error.URLError, TimeoutError, KeyError, ValueError) as error:
    print(f"Admin-Anmeldung nicht möglich: {type(error).__name__}", file=sys.stderr)
    sys.exit(2)
PYTHON
)
unset ADMIN_PASSWORD ADMIN_OTP
if "$token_only"; then
  printf '%s\n' "$TOKEN"
  exit 0
fi

kcadm() {
  docker exec -i "$CONTAINER" /opt/keycloak/bin/kcadm.sh "$@" \
    --no-config --server "$KCADM_SERVER" --realm master --token "$TOKEN"
}

realm_json=$(kcadm get "realms/$REALM")
flow_alias=$(printf '%s' "$realm_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["browserFlow"])')
flow_json=$(kcadm get "authentication/flows/${flow_alias// /%20}/executions" -r "$REALM")
master_flow=$(kcadm get realms/master | python3 -c 'import json,sys; print(json.load(sys.stdin)["browserFlow"])')
master_flow_json=$(kcadm get "authentication/flows/${master_flow// /%20}/executions" -r master)
profiles_json=$(kcadm get client-policies/profiles -r "$REALM")
policies_json=$(kcadm get client-policies/policies -r "$REALM")

python3 - "$realm_json" "$flow_json" "$master_flow_json" "$profiles_json" "$policies_json" <<'EOF'
import json, re, sys

realm, flow, master_flow, profiles, policies = (json.loads(a) for a in sys.argv[1:6])
GREEN, RED, RESET = "\033[32m", "\033[31m", "\033[0m"

def policy(name):
    m = re.search(rf"{name}\((\d+)\)", realm.get("passwordPolicy", ""))
    return int(m.group(1)) if m else None

def otp_required(executions):
    # OTP Form direkt im forms-Subflow (level 1) und Required: kein Pfad ohne zweiten Faktor
    return any(e.get("providerId") == "auth-otp-form" and e["requirement"] == "REQUIRED"
               and e.get("level", 99) <= 1 for e in executions)

def has_secret_rotation():
    rotation_profiles = {p["name"] for p in profiles.get("profiles", [])
                         if any(ex.get("executor") == "secret-rotation" for ex in p.get("executors", []))}
    return any(p.get("enabled") and rotation_profiles.intersection(p.get("profiles", []))
               and any(c.get("condition") == "client-access-type"
                       and "confidential" in c.get("configuration", {}).get("type", [])
                       for c in p.get("conditions", []))
               for p in policies.get("policies", []))

lockout = realm.get("bruteForceProtected") and (
    realm.get("permanentLockout") or realm.get("waitIncrementSeconds", 0) >= 1800)

checks = [
    ("8.2.8  SSO Session Idle <= 15 min", realm.get("ssoSessionIdleTimeout", 0) <= 900,
     f'{realm.get("ssoSessionIdleTimeout", 0) // 60} min'),
    ("8.3.4  Sperre nach <= 10 Versuchen", realm.get("bruteForceProtected") and realm.get("failureFactor", 99) <= 10,
     f'{realm.get("failureFactor")} Versuche'),
    ("8.3.4  Sperre >= 30 min oder permanent", bool(lockout),
     "permanent" if realm.get("permanentLockout") else f'{realm.get("waitIncrementSeconds", 0) // 60} min'),
    ("8.3.6  Passwort >= 12 Zeichen", (policy("length") or 0) >= 12, f'length({policy("length")})'),
    ("8.3.7  Historie >= 4", (policy("passwordHistory") or 0) >= 4, f'passwordHistory({policy("passwordHistory")})'),
    ("8.3.9  Ablauf <= 90 Tage", 0 < (policy("forceExpiredPasswordChange") or 0) <= 90,
     f'forceExpiredPasswordChange({policy("forceExpiredPasswordChange")})'),
    ("8.4.1  OTP Required im Realm master", otp_required(master_flow), "Realm master"),
    ("8.4.2  OTP Required im Browser-Flow", otp_required(flow), "Flow " + realm.get("browserFlow", "")),
    ("8.6.3  Client Policy secret-rotation", has_secret_rotation(), "Aktive Policy mit Profil für confidential Clients"),
    ("7.2.1  Admin Permissions aktiv", realm.get("adminPermissionsEnabled", False), ""),
    ("10.2.1 User Events gespeichert", realm.get("eventsEnabled", False), ""),
    ("10.2.1 Admin Events mit Representation",
     realm.get("adminEventsEnabled", False) and realm.get("adminEventsDetailsEnabled", False), ""),
    ("10.5.1 Retention >= 90 Tage", realm.get("eventsExpiration", 0) >= 90 * 86400,
     f'{realm.get("eventsExpiration", 0) // 86400} Tage'),
    ("10.5.1 jboss-logging aktiv", "jboss-logging" in realm.get("eventsListeners", []), ""),
]

failed = 0
for label, ok, detail in checks:
    mark = f"{GREEN}PASS{RESET}" if ok else f"{RED}FAIL{RESET}"
    print(f"{mark}  {label:45} {detail}")
    failed += not ok
print(f"\n{len(checks) - failed}/{len(checks)} Prüfungen bestanden")
sys.exit(1 if failed else 0)
EOF
