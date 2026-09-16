# Modul 10c: Client-Secrets und Signaturschlüssel rotieren

## Übungsziel

Am Ende dieser Übung hast du:

- Ein Client-Secret mit einer Übergangszeit gewechselt und das alte Secret ungültig gemacht
- Bereits ausgestellte Tokens nach der Secret-Rotation an einer API geprüft
- Einen neuen Signaturschlüssel aktiviert und die `kid` alter und neuer Tokens verglichen
- Den Unterschied zwischen einem passiven und einem deaktivierten Schlüssel sowie den JWKS-Cache beobachtet

## Ausgangslage

Der `sync-service` der Mustertech GmbH ruft eine geschützte API auf. Heute wechselst du
sein Client-Secret. Während der Umstellung sollen das alte und das neue Secret kurzzeitig
funktionieren, danach nur noch das neue. Was passiert dabei mit Tokens, die der Dienst
schon besitzt?

Im zweiten Teil wechselst du den Signaturschlüssel des Realms. Auch hier prüfst du an der
API, ob ältere Tokens noch angenommen werden. Dafür verwendest du dieselben gespeicherten
Tokens vor und nach der Änderung.

```text
sync-service -- Token-Anfrage: Client-ID + Secret --> Keycloak
sync-service <-- signiertes Access Token ---------- Keycloak

sync-service -- API-Anfrage mit Access Token ------> Portal-API
Portal-API   -- GET auf den JWKS-Endpunkt ----------> Keycloak
Portal-API   <-- JWKS mit öffentlichen Schlüsseln --- Keycloak
sync-service <-- Antwort nach Token-Prüfung -------- Portal-API
```

Das Secret authentifiziert den Client am Token-Endpunkt. Den privaten Signaturschlüssel
verwendet Keycloak zum Signieren; die API prüft die Signatur mit dem öffentlichen Schlüssel.
Liegt der passende öffentliche Schlüssel bereits im API-Cache, entfällt der JWKS-Abruf.
Im Lab übernimmt dein Terminal die Anfragen des `sync-service`: Du sendest das Secret an
Keycloaks Token-Endpunkt und das erhaltene Token anschließend als Bearer-Token an die API.

## Voraussetzungen

- Docker Desktop und Docker Compose mit `--wait`-Unterstützung
- Grundkenntnisse zu Clients, Access Tokens und Token-Prüfung aus Modul 06
- Bash mit `curl` ab 7.76 und `jq`, oder PowerShell ab 7.1 (`pwsh`)
- Unter Windows PowerShell 7 oder die Ubuntu-Sitzung aus der [Windows-Einrichtung](../../WINDOWS.md);
  Windows PowerShell 5.1 unterstützt die verwendeten Befehle nicht

Das Lab ist eigenständig und kann auch nach Modul 12 durchgeführt werden. Es verwendet
Keycloak 26.5.7 und für die Secret-Übergangszeit das Preview-Feature `client-secret-rotation`.

> **Hinweis:** Stoppe vor dem Start die Container der vorherigen Übung mit
> `docker compose down -v` in deren Verzeichnis, wenn sie die Ports 8080 oder 3001 belegen.
> Dabei werden deren Lab-Daten gelöscht. Siehe [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).
> 10c hat eigene Volumes im Compose-Projekt `keycloak-10c`.

Wechsle vom Verzeichnis `labs/` in das Lab und starte die Dienste:

```bash
cd assignments/modul-10c-rotation
docker compose up -d --build --wait --wait-timeout 240
docker compose run --rm setup
```

Der Setup-Schritt verwendet einmalig das offizielle Keycloak-Image, um den lokalen
Admin-Zugang vorzubereiten. Alle folgenden HTTP-Aufrufe laufen direkt in deiner Shell.

Warte auf den erfolgreichen Abschluss beider Befehle. Öffne <http://localhost:8080/admin/>
und melde dich mit `admin` / `admin` an. Wähle den Realm **mustertech**.

Der Realm enthält den vertraulichen Client `sync-service` mit Service Account; als API läuft
die Portal-API aus Modul 06. Die Client Policy `lab-confidential` verwendet das Profil
`lab-rotation`. Dadurch gilt ein neues Secret einen Tag, während das bisherige nach der
Rotation noch eine Stunde akzeptiert wird. Auch die Tokens gelten im Lab eine Stunde,
damit sie während der Versuche nicht nebenbei ablaufen.

Diese Laufzeiten sind für die Übung gewählt. Die Verbindungen laufen lokal über HTTP;
im Produktivbetrieb brauchst du TLS und Laufzeiten, die zu deinen Anwendungen passen.

### Terminal vorbereiten

Wähle die Befehle für deine Shell und bleibe während der gesamten Übung in demselben Terminal.
Secrets und Tokens liegen in Shell-Variablen. Wenn du das Terminal schließt, gehen sie verloren.
Die mit **Bash** oder **PowerShell** bezeichneten Blöcke sind Alternativen; führe nur deine Variante aus.
Die Docker-Befehle ohne solche Kennzeichnung gelten für beide Shells.

Öffne für die Bash-Variante zuerst mit `bash` eine Bash-Sitzung. Das gilt auch unter macOS,
wenn dein Terminal sonst Zsh verwendet.

Prüfe dann die Werkzeuge und lege die drei Zieladressen fest. Bei Bash zeigt `curl --version`
die installierte Version. `jq` liest JSON; es übernimmt keine HTTP-Anfragen.

**Bash:**

```bash
bash --version
curl --version
jq --version
set -o pipefail
TOKEN_URL='http://localhost:8080/realms/mustertech/protocol/openid-connect/token'
JWKS_URL='http://localhost:8080/realms/mustertech/protocol/openid-connect/certs'
API_URL='http://localhost:3001'
```

**PowerShell:**

```powershell
$PSVersionTable.PSVersion
$ErrorActionPreference = 'Stop'
$TOKEN_URL = 'http://localhost:8080/realms/mustertech/protocol/openid-connect/token'
$JWKS_URL = 'http://localhost:8080/realms/mustertech/protocol/openid-connect/certs'
$API_URL = 'http://localhost:3001'
```

Falls `jq` fehlt: Unter Ubuntu installierst du es mit `sudo apt-get install jq`, unter macOS
mit `brew install jq`. Für PowerShell brauchst du weder `curl` noch `jq`.

### Token-Header lokal lesen

Definiere einmal die folgende Funktion. Sie zerlegt das JWT an den Punkten, dekodiert die
Base64URL-Daten aus Header und Payload und zeigt `kid`, Algorithmus, Issuer und Restlaufzeit.
**Sie prüft keine Signatur und sendet keine Anfrage.** Die Signaturprüfung übernimmt später die API.

**Bash:**

```bash
show_token() {
  printf '%s' "$1" | jq -R '
    def decode: gsub("-"; "+") | gsub("_"; "/") | @base64d | fromjson;
    split(".") as $parts |
    ($parts[0] | decode) as $header |
    ($parts[1] | decode) as $claims |
    {alg: $header.alg, kid: $header.kid, iss: $claims.iss,
     Restlaufzeit_Sekunden: (($claims.exp - now) | floor)}'
}
```

**PowerShell:**

```powershell
function Show-Token([string]$Token) {
    $parts = $Token.Split('.')
    $decoded = foreach ($part in $parts[0..1]) {
        $base64 = $part.Replace('-', '+').Replace('_', '/')
        $base64 = $base64.PadRight($base64.Length + (4 - $base64.Length % 4) % 4, '=')
        [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64)) | ConvertFrom-Json
    }
    [pscustomobject]@{
        alg = $decoded[0].alg
        kid = $decoded[0].kid
        iss = $decoded[1].iss
        Restlaufzeit_Sekunden = $decoded[1].exp - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
}
```

Jede Token-Anfrage unten zeigt den vollständigen OAuth-Request: `grant_type=client_credentials`,
`client_id` und `client_secret` werden als Formulardaten an `/token` gesendet.
Bei Bash liest `--data-urlencode client_secret@-` das Secret aus der Standardeingabe.
Bei PowerShell steht es im `Body` der Anfrage. Der anschließende API-Aufruf verwendet dagegen
nur das Token im Header `Authorization: Bearer ...`.

Die Secret-Eingabe bleibt in Bash unsichtbar; PowerShell zeigt Platzhalter. Füge das Secret
gegebenenfalls per Rechtsklick ein. Die vollständigen Tokens werden nicht ausgegeben.
Führe die Befehle einzeln aus und vergleiche die Antworten mit den Erwartungen.
Bei einem unerwarteten Fehler klärst du die Ursache, bevor du weiterarbeitest.

## Teil 1: Client-Secret wechseln

### Schritt 1.1: Ausgangszustand prüfen

Öffne **Clients** -> **sync-service** -> **Credentials**. Kopiere das aktuelle **Client secret**.
Lies es in die Variable `OLD_SECRET` ein:

**Bash:**

```bash
read -r -s -p "Client-Secret einfügen: " OLD_SECRET
printf '\n'
```

**PowerShell:**

```powershell
$OLD_SECRET = Read-Host "Client-Secret einfügen" -MaskInput
```

Füge das Secret bei der Eingabeaufforderung ein. Fordere damit ein Token an, lege es in
`TOKEN_BEFORE` ab und rufe die API auf:

**Bash:**

```bash
TOKEN_BEFORE=$(printf '%s' "$OLD_SECRET" | curl --silent --show-error --fail-with-body \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  "$TOKEN_URL" | jq -er '.access_token // empty')
show_token "$TOKEN_BEFORE"

curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_BEFORE" "$API_URL/api/profile"
```

**PowerShell:**

```powershell
$TOKEN_BEFORE = $null
$TOKEN_BEFORE = (Invoke-RestMethod -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $OLD_SECRET
} -ContentType 'application/x-www-form-urlencoded').access_token
Show-Token $TOKEN_BEFORE

$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_BEFORE"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content
```

**Erwartet:** Die Token-Anfrage gelingt und zeigt die dekodierten Felder. Die API antwortet mit
HTTP 200 und dem Benutzernamen `service-account-sync-service`.
Notiere die `kid` des Tokens. An ihr erkennst du, welchen Signaturschlüssel die API zur Prüfung braucht.

### Schritt 1.2: Secret mit Übergangszeit rotieren

Klicke bei **Client secret** auf **Regenerate** und bestätige gegebenenfalls den Dialog.
Die Credentials-Seite zeigt nun das aktuelle und das rotierte Secret samt Ablaufzeit.
Kopiere das **neue aktuelle** Secret und lies es in `NEW_SECRET` ein:

**Bash:**

```bash
read -r -s -p "Client-Secret einfügen: " NEW_SECRET
printf '\n'

TOKEN_OVERLAP_OLD=$(printf '%s' "$OLD_SECRET" | curl --silent --show-error --fail-with-body \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  "$TOKEN_URL" | jq -er '.access_token // empty')
show_token "$TOKEN_OVERLAP_OLD"

TOKEN_OVERLAP_NEW=$(printf '%s' "$NEW_SECRET" | curl --silent --show-error --fail-with-body \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  "$TOKEN_URL" | jq -er '.access_token // empty')
show_token "$TOKEN_OVERLAP_NEW"
```

**PowerShell:**

```powershell
$NEW_SECRET = Read-Host "Client-Secret einfügen" -MaskInput

$TOKEN_OVERLAP_OLD = $null
$TOKEN_OVERLAP_OLD = (Invoke-RestMethod -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $OLD_SECRET
} -ContentType 'application/x-www-form-urlencoded').access_token
Show-Token $TOKEN_OVERLAP_OLD

$TOKEN_OVERLAP_NEW = $null
$TOKEN_OVERLAP_NEW = (Invoke-RestMethod -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $NEW_SECRET
} -ContentType 'application/x-www-form-urlencoded').access_token
Show-Token $TOKEN_OVERLAP_NEW
```

**Erwartet:** Beide Token-Anfragen gelingen und liefern dekodierbare Tokens. Die vorbereitete
Policy ermöglicht diese Übergangszeit. Vergleiche die `kid` beider Tokens mit `TOKEN_BEFORE`: Sie hat sich nicht geändert.

### Schritt 1.3: Altes Secret ungültig machen

**Entscheide zuerst:** Im Produktivbetrieb laufen zwei Instanzen des `sync-service`.
Instanz A verwendet bereits das neue Secret, Instanz B noch das alte. Beide können die API
gerade erfolgreich aufrufen, weil sie noch gültige Tokens besitzen.

Darf das alte Secret jetzt invalidiert werden? Notiere deine Entscheidung mit einer Begründung
und benenne die Anfrage, die du vor dem Abschalten auf jeder Instanz erfolgreich prüfen müsstest.
Für diese Frage musst du keine weiteren Container starten.

Im Lab hast du das neue Secret bereits mit einer Token-Anfrage geprüft. Führe hier den Wechsel zu Ende:
Auf derselben Credentials-Seite klicke beim **Rotated secret** auf **Invalidate** und bestätige.
Teste danach dieselben Anmeldeinformationen erneut:

**Bash:**

```bash
printf '%s' "$OLD_SECRET" | curl --silent --show-error \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  --write-out '\nHTTP %{http_code}\n' "$TOKEN_URL"

TOKEN_AFTER_SECRET=$(printf '%s' "$NEW_SECRET" | curl --silent --show-error --fail-with-body \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  "$TOKEN_URL" | jq -er '.access_token // empty')
show_token "$TOKEN_AFTER_SECRET"
```

**PowerShell:**

```powershell
$response = Invoke-WebRequest -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $OLD_SECRET
} -ContentType 'application/x-www-form-urlencoded' -SkipHttpErrorCheck
$response.StatusCode
$response.Content

$TOKEN_AFTER_SECRET = $null
$TOKEN_AFTER_SECRET = (Invoke-RestMethod -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $NEW_SECRET
} -ContentType 'application/x-www-form-urlencoded').access_token
Show-Token $TOKEN_AFTER_SECRET
```

**Erwartet:** Das alte Secret erhält HTTP 401 mit `unauthorized_client`. Mit dem neuen Secret
erhältst du ein frisches Token in `TOKEN_AFTER_SECRET`. Der absichtlich fehlschlagende Aufruf
speichert kein Token. `--write-out` beziehungsweise `StatusCode` macht den HTTP-Status sichtbar;
`-SkipHttpErrorCheck` lässt PowerShell auch die erwartete 401-Antwort anzeigen.

Prüfe nun das **vor der Rotation ausgestellte** Token an der API:

**Bash:**

```bash
curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_BEFORE" "$API_URL/api/profile"
```

**PowerShell:**

```powershell
$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_BEFORE"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content
```

**Erwartet:** HTTP 200, solange das Token noch nicht abgelaufen ist.
Die API prüft das vorgelegte Access Token anhand seiner Signatur und Claims.
Dass Keycloak das alte Client-Secret inzwischen ablehnt, erfährt sie dabei nicht.

## Teil 2: Signaturschlüssel wechseln

### Schritt 2.1: Alten Schlüssel finden

Hole unmittelbar vor diesem Versuch ein Token mit dem gültigen neuen Secret:

**Bash:**

```bash
TOKEN_KEY_BEFORE=$(printf '%s' "$NEW_SECRET" | curl --silent --show-error --fail-with-body \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  "$TOKEN_URL" | jq -er '.access_token // empty')
show_token "$TOKEN_KEY_BEFORE"

curl --silent --show-error --fail-with-body "$JWKS_URL" | jq '.keys[] | {kid, alg, use}'
```

**PowerShell:**

```powershell
$TOKEN_KEY_BEFORE = $null
$TOKEN_KEY_BEFORE = (Invoke-RestMethod -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $NEW_SECRET
} -ContentType 'application/x-www-form-urlencoded').access_token
Show-Token $TOKEN_KEY_BEFORE

(Invoke-RestMethod -Uri $JWKS_URL).keys | Select-Object kid, alg, use
```

Notiere die `kid` von `TOKEN_KEY_BEFORE`. Suche sie in der JWKS-Ausgabe; dort gehört sie zu
`alg: RS256` und `use: sig`. Weitere Schlüssel können anderen Algorithmen oder Zwecken dienen.

Öffne **Realm settings** -> **Keys**. Finde unter Keys die kid des Providers rsa-original und 
vergleiche sie mit der kid von `TOKEN_KEY_BEFORE`.
Wechsle zu **Providers** und öffne **rsa-original**. Im Feld **Priority** steht `100`.
Kehre anschließend über **Keys** zur Provider-Liste zurück.

### Schritt 2.2: Einen neuen Schlüssel aktivieren

Unter **Keys** -> **Providers** wähle **Add provider** -> **rsa-generated**.
Konfiguriere:

| Einstellung | Wert           |
| ----------- | -------------- |
| Name        | `rsa-rotation` |
| Priority    | `200`          |
| Enabled     | On             |
| Active      | On             |
| Algorithm   | `RS256`        |
| Key size    | `2048`         |

Speichere und fordere ein neues Token an:

**Bash:**

```bash
TOKEN_KEY_AFTER=$(printf '%s' "$NEW_SECRET" | curl --silent --show-error --fail-with-body \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  "$TOKEN_URL" | jq -er '.access_token // empty')
show_token "$TOKEN_KEY_AFTER"

curl --silent --show-error --fail-with-body "$JWKS_URL" | jq '.keys[] | {kid, alg, use}'

curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_KEY_BEFORE" "$API_URL/api/profile"

curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_KEY_AFTER" "$API_URL/api/profile"
```

**PowerShell:**

```powershell
$TOKEN_KEY_AFTER = $null
$TOKEN_KEY_AFTER = (Invoke-RestMethod -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $NEW_SECRET
} -ContentType 'application/x-www-form-urlencoded').access_token
Show-Token $TOKEN_KEY_AFTER

(Invoke-RestMethod -Uri $JWKS_URL).keys | Select-Object kid, alg, use

$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_KEY_BEFORE"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content

$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_KEY_AFTER"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content
```

**Erwartet:** Das neue Token hat eine andere `kid`. Beide öffentlichen Signaturschlüssel
stehen im JWKS und beide Tokens werden von der API mit HTTP 200 akzeptiert.
Das neue Schlüsselpaar wird wegen seiner höheren Priorität für neue RS256-Tokens verwendet.

### Schritt 2.3: Alten Schlüssel passiv machen

Öffne den Provider **rsa-original**. Stelle **Active** auf **Off**, lasse **Enabled** auf **On**
und speichere. Teste das alte Token erneut:

**Bash:**

```bash
curl --silent --show-error --fail-with-body "$JWKS_URL" | jq '.keys[] | {kid, alg, use}'

curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_KEY_BEFORE" "$API_URL/api/profile"
```

**PowerShell:**

```powershell
(Invoke-RestMethod -Uri $JWKS_URL).keys | Select-Object kid, alg, use

$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_KEY_BEFORE"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content
```

**Erwartet:** Der alte öffentliche Schlüssel bleibt veröffentlicht; das alte Token funktioniert.
Mit **Active: Off** schaltest du das Signieren mit diesem Schlüssel aus. Solange **Enabled: On**
bleibt, können Anwendungen den öffentlichen Schlüssel weiterhin abrufen und ältere Tokens prüfen.

**Vorhersage vor dem nächsten Klick:** Du erhöhst die Priorität von `rsa-original` auf `300`,
lässt den Provider aber passiv. `rsa-rotation` bleibt aktiv mit Priorität `200`.
Welcher Provider wird das nächste Token signieren? Notiere seine erwartete `kid` und begründe
deine Wahl anhand von **Active** und **Priority**.

Stelle nun bei `rsa-original` nur **Priority** auf `300` und speichere. Fordere ein frisches Token an:

**Bash:**

```bash
TOKEN_PRIORITY_CHECK=$(printf '%s' "$NEW_SECRET" | curl --silent --show-error --fail-with-body \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=sync-service \
  --data-urlencode client_secret@- \
  "$TOKEN_URL" | jq -er '.access_token // empty')
show_token "$TOKEN_PRIORITY_CHECK"
```

**PowerShell:**

```powershell
$TOKEN_PRIORITY_CHECK = $null
$TOKEN_PRIORITY_CHECK = (Invoke-RestMethod -Method Post -Uri $TOKEN_URL -Body @{
    grant_type = 'client_credentials'
    client_id = 'sync-service'
    client_secret = $NEW_SECRET
} -ContentType 'application/x-www-form-urlencoded').access_token
Show-Token $TOKEN_PRIORITY_CHECK
```

Vergleiche die ausgegebene `kid` mit deiner Vorhersage. Erkläre eine Abweichung, bevor du
fortfährst. Stelle anschließend **Priority** wieder auf `100`; **Active: Off** und **Enabled: On** bleiben stehen.

### Schritt 2.4: Alten Schlüssel deaktivieren und den Cache prüfen

Jetzt deaktivierst du den alten Schlüssel, obwohl `TOKEN_KEY_BEFORE` noch gültig ist.
Damit untersuchst du, was bei einer zu kurzen Übergangszeit passiert. Im Produktivbetrieb
müsstest du zuvor die Laufzeiten aller betroffenen Token-Arten und die Schlüssel-Caches der
Anwendungen berücksichtigen.

Beginne mit einem frisch gefüllten Cache. Solange `rsa-original` noch **Enabled: On** ist,
starte die API neu und rufe sie mit dem alten Token auf:

**Bash:**

```bash
show_token "$TOKEN_KEY_BEFORE"

docker compose restart api

docker compose up -d --wait --wait-timeout 60 api

curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_KEY_BEFORE" "$API_URL/api/profile"
```

**PowerShell:**

```powershell
Show-Token $TOKEN_KEY_BEFORE

docker compose restart api

docker compose up -d --wait --wait-timeout 60 api

$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_KEY_BEFORE"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content
```

`TOKEN_KEY_BEFORE` muss noch mindestens fünf Minuten gültig sein; der API-Aufruf muss HTTP 200 liefern.
Der Neustart entfernt ältere Cache-Einträge, der Aufruf lädt den alten Schlüssel neu.
Führe die folgenden Schritte bis zur nächsten API-Anfrage innerhalb einer Minute aus.

Stelle bei **rsa-original** jetzt zusätzlich **Enabled** auf **Off** und speichere.
Prüfe das JWKS:

**Bash:**

```bash
curl --silent --show-error --fail-with-body "$JWKS_URL" | jq '.keys[] | {kid, alg, use}'
```

**PowerShell:**

```powershell
(Invoke-RestMethod -Uri $JWKS_URL).keys | Select-Object kid, alg, use
```

**Erwartet:** Die `kid` von `TOKEN_KEY_BEFORE` fehlt. Prüfe jetzt dasselbe Token an der API:

**Bash:**

```bash
curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_KEY_BEFORE" "$API_URL/api/profile"
```

**PowerShell:**

```powershell
$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_KEY_BEFORE"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content
```

**Erwartet:** HTTP 200. Obwohl der Schlüssel im JWKS fehlt, kann die API ihn aus ihrem Cache verwenden.
Bei HTTP 401 ist dieser Cache-Effekt noch nicht nachgewiesen. Stelle `rsa-original` wieder auf
**Enabled: On**, prüfe seine `kid` im JWKS und wiederhole diesen Schritt ab dem Füllen des Caches.
Falls die Token-Laufzeit nicht mehr reicht, setze das Lab zurück und beginne erneut.

Leere für eine reproduzierbare Gegenprobe den Prozess-Cache durch einen Neustart ausschließlich der API:

**Bash:**

```bash
docker compose restart api

docker compose up -d --wait --wait-timeout 60 api

curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_KEY_BEFORE" "$API_URL/api/profile"

curl --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  --header "Authorization: Bearer $TOKEN_KEY_AFTER" "$API_URL/api/profile"
```

**PowerShell:**

```powershell
docker compose restart api

docker compose up -d --wait --wait-timeout 60 api

$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_KEY_BEFORE"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content

$response = Invoke-WebRequest -Uri "$API_URL/api/profile" -Headers @{
    Authorization = "Bearer $TOKEN_KEY_AFTER"
} -SkipHttpErrorCheck
$response.StatusCode
$response.Content
```

**Erwartet:** Das alte Token erhält HTTP 401, das neue weiterhin HTTP 200. Durch den Neustart
musste die API die Schlüssel neu abrufen. Erst der Wechsel von **200 vor dem Neustart zu 401 danach**
zeigt hier den Einfluss des Caches. Das Entfernen aus dem JWKS allein hatte den Zugriff noch nicht verhindert.

### Schritt 2.5: Übergangszustand wiederherstellen

Aktiviere bei **rsa-original** wieder **Enabled: On**, lasse **Active: Off**.
Prüfe zuerst, dass die alte `kid` wieder im JWKS steht. Starte anschließend die API wie in
Schritt 2.4 neu und wiederhole beide Token-Prüfungen mit der Erwartung HTTP 200.
So endest du mit einem neuen aktiven und einem alten passiven Schlüssel.

## Nachsehen und wiederholen

Bei abweichenden Ergebnissen helfen die [Diagnoseschritte für 10c](../TROUBLESHOOTING.md#rotation-in-modul-10c).
Mit der Dekodierfunktion kannst du die `kid` und Restlaufzeit des alten Tokens noch einmal ansehen:

**Bash:**

```bash
show_token "$TOKEN_KEY_BEFORE"
```

**PowerShell:**

```powershell
Show-Token $TOKEN_KEY_BEFORE
```

Die Funktion dekodiert Header und Claims, ohne die Signatur zu prüfen. Dafür rufst du die API auf;
sie prüft auch den Issuer und die Laufzeit. Du brauchst keine öffentliche Decoder-Webseite.

Für einen vollständigen Neustart oder nach Abschluss:

```bash
docker compose down -v
```

Der Befehl räumt die gestarteten Lab-Dienste und die Datenbank auf. Schließe anschließend das
Terminal, um Secrets und Tokens aus
den Shell-Variablen zu entfernen. Für einen neuen Durchlauf beginnst du wieder bei
"Voraussetzungen": Dienste starten, Setup ausführen und anschließend das Terminal vorbereiten.
Ein erneuter Start stellt den Importzustand her.

## Quellen und Trainerunterlage

- [Keycloak: Signaturschlüssel rotieren](https://www.keycloak.org/docs/latest/server_admin/index.html#rotating-keys)
- [Keycloak: Client-Secret-Rotation](https://www.keycloak.org/docs/latest/server_admin/index.html#_secret_rotation)
- [Musterlösung und Trainerhinweise](trainer.md)
