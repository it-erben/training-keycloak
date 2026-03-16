#!/usr/bin/env bash
# ============================================
# Setup-Skript für Modul 07: Identity Provider
# ============================================
# Erstellt Admin- und Test-User in Gitea und
# legt eine OAuth2-Application an.
#
# Verwendung: bash setup.sh

set -euo pipefail

GITEA_URL="http://localhost:3000"
GITEA_ADMIN_USER="gitea-admin"
GITEA_ADMIN_PASS="admin1234"
GITEA_ADMIN_EMAIL="admin@example.com"
GITEA_TEST_USER="alice"
GITEA_TEST_PASS="demo1234"
GITEA_TEST_EMAIL="alice@gitea.local"
KEYCLOAK_CALLBACK="http://localhost:8080/realms/mustertech/broker/gitea/endpoint"

echo "=== Gitea Setup für Modul 07 ==="
echo ""

# --- 1. Warten bis Gitea bereit ist ---
echo "Warte auf Gitea API..."
for i in $(seq 1 30); do
  if curl -sf "${GITEA_URL}/api/v1/version" > /dev/null 2>&1; then
    echo "Gitea ist bereit."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "FEHLER: Gitea nicht erreichbar nach 30 Sekunden."
    exit 1
  fi
  sleep 1
done

echo ""

# --- 2. Admin-User erstellen ---
echo "Erstelle Gitea Admin-User '${GITEA_ADMIN_USER}'..."
docker exec assignment-gitea gitea admin user create \
  --username "${GITEA_ADMIN_USER}" \
  --password "${GITEA_ADMIN_PASS}" \
  --email "${GITEA_ADMIN_EMAIL}" \
  --admin \
  --must-change-password=false 2>/dev/null || echo "(User existiert bereits)"

echo ""

# --- 3. Test-User erstellen ---
echo "Erstelle Gitea Test-User '${GITEA_TEST_USER}'..."
curl -sf -X POST "${GITEA_URL}/api/v1/admin/users" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"${GITEA_TEST_USER}\",
    \"password\": \"${GITEA_TEST_PASS}\",
    \"email\": \"${GITEA_TEST_EMAIL}\",
    \"must_change_password\": false
  }" > /dev/null 2>&1 || echo "(User existiert bereits)"

echo ""

# --- 4. OAuth2-Application erstellen ---
echo "Erstelle OAuth2-Application in Gitea..."
OAUTH_RESPONSE=$(curl -sf -X POST "${GITEA_URL}/api/v1/user/applications/oauth2" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Keycloak Assignment\",
    \"redirect_uris\": [\"${KEYCLOAK_CALLBACK}\"],
    \"confidential_client\": true
  }" 2>/dev/null)

if [ -z "${OAUTH_RESPONSE}" ]; then
  echo "FEHLER: OAuth2-Application konnte nicht erstellt werden."
  echo "Möglicherweise existiert sie bereits. Lösche sie in Gitea unter:"
  echo "  ${GITEA_URL}/user/settings/applications (eingeloggt als ${GITEA_ADMIN_USER})"
  exit 1
fi

CLIENT_ID=$(echo "${OAUTH_RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['client_id'])")
CLIENT_SECRET=$(echo "${OAUTH_RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['client_secret'])")

echo ""
echo "==========================================="
echo " Gitea Setup abgeschlossen"
echo "==========================================="
echo ""
echo " Gitea URL:       ${GITEA_URL}"
echo " Test-User:       ${GITEA_TEST_USER} / ${GITEA_TEST_PASS}"
echo ""
echo " OAuth2 Credentials (für Keycloak IdP):"
echo " ----------------------------------------"
echo " Client ID:       ${CLIENT_ID}"
echo " Client Secret:   ${CLIENT_SECRET}"
echo ""
echo " Nächste Schritte in Keycloak:"
echo " 1. Identity providers -> Add provider -> OpenID Connect v1.0"
echo " 2. Alias: gitea"
echo " 3. Discovery endpoint deaktivieren!"
echo "    Authorization URL: ${GITEA_URL}/login/oauth/authorize"
echo "    Token URL:         http://assignment-gitea:3000/login/oauth/access_token"
echo "    User Info URL:     http://assignment-gitea:3000/login/oauth/userinfo"
echo " 4. Client ID und Client Secret eintragen"
echo " 5. Save"
echo "==========================================="
