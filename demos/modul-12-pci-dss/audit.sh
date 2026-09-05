#!/usr/bin/env bash
# Prüft den Realm mustertech des Lab-Stacks gegen PCI-DSS-Grenzwerte.
# Liest über kcadm.sh im Container assignment-keycloak; braucht python3 auf dem Host.
set -euo pipefail

CONTAINER="${CONTAINER:-assignment-keycloak}"
REALM="${REALM:-mustertech}"
KCADM="docker exec -i $CONTAINER /opt/keycloak/bin/kcadm.sh"

$KCADM config credentials --server http://localhost:8080 --realm master \
  --user admin --password admin >/dev/null

realm_json=$($KCADM get "realms/$REALM")
flow_alias=$(printf '%s' "$realm_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["browserFlow"])')
flow_json=$($KCADM get "authentication/flows/${flow_alias// /%20}/executions" -r "$REALM")
master_flow=$($KCADM get realms/master | python3 -c 'import json,sys; print(json.load(sys.stdin)["browserFlow"])')
master_flow_json=$($KCADM get "authentication/flows/${master_flow// /%20}/executions" -r master)
profiles_json=$($KCADM get client-policies/profiles -r "$REALM")

python3 - "$realm_json" "$flow_json" "$master_flow_json" "$profiles_json" <<'EOF'
import json, re, sys

realm, flow, master_flow, profiles = (json.loads(a) for a in sys.argv[1:5])
GREEN, RED, RESET = "\033[32m", "\033[31m", "\033[0m"

def policy(name):
    m = re.search(rf"{name}\((\d+)\)", realm.get("passwordPolicy", ""))
    return int(m.group(1)) if m else None

def otp_required(executions):
    # OTP Form direkt im forms-Subflow (level 1) und Required: kein Pfad ohne zweiten Faktor
    return any(e.get("providerId") == "auth-otp-form" and e["requirement"] == "REQUIRED"
               and e.get("level", 99) <= 1 for e in executions)

def has_secret_rotation():
    return any(ex.get("executor") == "secret-rotation"
               for p in profiles.get("profiles", []) for ex in p.get("executors", []))

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
    ("8.6.3  Client Policy secret-rotation", has_secret_rotation(), "Profile mit Executor"),
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
