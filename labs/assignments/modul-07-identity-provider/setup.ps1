# ============================================
# Setup-Skript für Modul 07: Identity Provider
# ============================================
# Erstellt Admin- und Test-User in Gitea und
# legt eine OAuth2-Application an.
#
# Verwendung: .\setup.ps1

$ErrorActionPreference = "Stop"

$GITEA_URL = "http://localhost:3000"
$GITEA_ADMIN_USER = "gitea-admin"
$GITEA_ADMIN_PASS = "admin1234"
$GITEA_ADMIN_EMAIL = "admin@example.com"
$GITEA_TEST_USER = "alice"
$GITEA_TEST_PASS = "demo1234"
$GITEA_TEST_EMAIL = "alice@gitea.local"
$KEYCLOAK_CALLBACK = "http://localhost:8080/realms/mustertech/broker/gitea/endpoint"

$AUTH_HEADER = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}")) }

Write-Host "=== Gitea Setup fuer Modul 07 ==="
Write-Host ""

# --- 1. Warten bis Gitea bereit ist ---
Write-Host "Warte auf Gitea API..."
for ($i = 1; $i -le 30; $i++) {
    try {
        Invoke-RestMethod -Uri "$GITEA_URL/api/v1/version" -ErrorAction Stop | Out-Null
        Write-Host "Gitea ist bereit."
        break
    } catch {
        if ($i -eq 30) {
            Write-Host "FEHLER: Gitea nicht erreichbar nach 30 Sekunden."
            exit 1
        }
        Start-Sleep -Seconds 1
    }
}

Write-Host ""

# --- 2. Admin-User erstellen ---
Write-Host "Erstelle Gitea Admin-User '$GITEA_ADMIN_USER'..."
try {
    docker exec assignment-gitea gitea admin user create `
        --username $GITEA_ADMIN_USER `
        --password $GITEA_ADMIN_PASS `
        --email $GITEA_ADMIN_EMAIL `
        --admin `
        --must-change-password=false 2>$null
} catch {
    Write-Host "(User existiert bereits)"
}
if ($LASTEXITCODE -ne 0) { Write-Host "(User existiert bereits)" }

Write-Host ""

# --- 3. Test-User erstellen ---
Write-Host "Erstelle Gitea Test-User '$GITEA_TEST_USER'..."
$testUserBody = @{
    username             = $GITEA_TEST_USER
    password             = $GITEA_TEST_PASS
    email                = $GITEA_TEST_EMAIL
    must_change_password = $false
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$GITEA_URL/api/v1/admin/users" `
        -Method Post `
        -Headers $AUTH_HEADER `
        -ContentType "application/json" `
        -Body $testUserBody `
        -ErrorAction Stop | Out-Null
} catch {
    Write-Host "(User existiert bereits)"
}

Write-Host ""

# --- 4. OAuth2-Application erstellen ---
Write-Host "Erstelle OAuth2-Application in Gitea..."
$oauthBody = @{
    name                = "Keycloak Assignment"
    redirect_uris       = @($KEYCLOAK_CALLBACK)
    confidential_client = $true
} | ConvertTo-Json

try {
    $oauthResponse = Invoke-RestMethod -Uri "$GITEA_URL/api/v1/user/applications/oauth2" `
        -Method Post `
        -Headers $AUTH_HEADER `
        -ContentType "application/json" `
        -Body $oauthBody `
        -ErrorAction Stop
} catch {
    Write-Host "FEHLER: OAuth2-Application konnte nicht erstellt werden."
    Write-Host "Moeglicherweise existiert sie bereits. Loesche sie in Gitea unter:"
    Write-Host "  $GITEA_URL/user/settings/applications (eingeloggt als $GITEA_ADMIN_USER)"
    exit 1
}

$CLIENT_ID = $oauthResponse.client_id
$CLIENT_SECRET = $oauthResponse.client_secret

Write-Host ""
Write-Host "==========================================="
Write-Host " Gitea Setup abgeschlossen"
Write-Host "==========================================="
Write-Host ""
Write-Host " Gitea URL:       $GITEA_URL"
Write-Host " Test-User:       $GITEA_TEST_USER / $GITEA_TEST_PASS"
Write-Host ""
Write-Host " OAuth2 Credentials (fuer Keycloak IdP):"
Write-Host " ----------------------------------------"
Write-Host " Client ID:       $CLIENT_ID"
Write-Host " Client Secret:   $CLIENT_SECRET"
Write-Host ""
Write-Host " Naechste Schritte in Keycloak:"
Write-Host " 1. Identity providers -> Add provider -> OpenID Connect v1.0"
Write-Host " 2. Alias: gitea"
Write-Host " 3. Discovery endpoint deaktivieren!"
Write-Host "    Authorization URL: $GITEA_URL/login/oauth/authorize"
Write-Host "    Token URL:         http://assignment-gitea:3000/login/oauth/access_token"
Write-Host "    User Info URL:     http://assignment-gitea:3000/login/oauth/userinfo"
Write-Host " 4. Client ID und Client Secret eintragen"
Write-Host " 5. Save"
Write-Host "==========================================="
