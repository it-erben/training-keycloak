# AD-Workshop auf GCP: Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein 90-minütiger Workshop unter `workshops/active-directory/`, in dem drei Zweiergruppen ihr lokales
Keycloak per LDAPS an ein selbst verwaltetes AD DS auf Google Compute Engine anbinden.

**Architecture:** Ein Windows-Server-2022-DC in einer eigenen Custom-VPC, per gcloud aus PowerShell 7 bereitgestellt.
AD-Konfiguration läuft als PowerShell im Gast über eine IAP-RDP-Sitzung. Teilnehmer arbeiten mit einem lokalen
Compose-Stack (Keycloak 26.5.7, PostgreSQL 18, Portal, Portal-API, LDAP-Werkzeugcontainer) gegen einen
quell-IP-beschränkten LDAPS-Endpunkt.

**Tech Stack:** gcloud CLI, PowerShell 7 mit Pester und PSScriptAnalyzer, Windows Server 2022 AD DS, Docker Compose,
Keycloak 26.5.7, OpenLDAP-Clients (Alpine), openssl.

**Spec:** `docs/superpowers/specs/2026-09-15-gcp-ad-workshop-design.md`

## Global Constraints

- Keycloak `quay.io/keycloak/keycloak:26.5.7`, PostgreSQL `postgres:18-alpine` mit Mount auf `/var/lib/postgresql`.
- Windows Server 2022 Datacenter, Image-Familie `windows-2022` aus `windows-cloud`, vor dem Erstellen auf den
  konkreten Image-Namen aufgelöst. Maschinentyp `e2-standard-2`, Bootdisk 64 GiB, Datendisk 20 GiB, beide pd-balanced.
- Domäne `ad.mustertech.test`, DC `dc01.ad.mustertech.test`, Basis `OU=Workshop,DC=ad,DC=mustertech,DC=test`
  mit `Team01`..`Team03`, darunter `Users`, `Moved`, `Groups`, `ServiceAccounts`.
- Eingehend ausschließlich TCP 636 aus den Gruppen-IPs und TCP 3389 aus `35.235.240.0/20`. Keine Regel aus `0.0.0.0/0`.
- VM ohne Service-Account-Identität. Keine Geheimnisse in Metadaten, Startskripten, Logs, Manifest oder Repository.
- Jeder gcloud-Aufruf mit `--project`, regionale/zonale Aufrufe zusätzlich mit `--region`/`--zone`.
- `-PlanOnly` verändert nichts. Vorhandene gleichnamige Ressourcen ohne Eigentumsnachweis führen zum Abbruch.
- Realm `mustertech`, Access Token 120 Sekunden, keine lokalen Konten mit den Namen der AD-Testbenutzer.
- Lokaler Stack mit eigenem Compose-Projektnamen `keycloak-ad-workshop`, ohne `container_name` und ohne
  globale Volume-Namen, Ports 8080, 5173, 3001.
- Alle Teilnehmerbefehle für Bash und PowerShell. Zertifikats- und Hostnamenprüfung bleiben immer aktiv.
- Gemeinsamer Code unter `labs/assignments/services/` wird nicht geändert.
- Deutsche Texte nach den Schreibregeln in `AGENTS.md`; Commits englisch, Conventional Commits, kein Coauthor-Trailer.

---

## Dateistruktur

```text
workshops/active-directory/
├── README.md                      Voraussetzungen, Start, Dauer, Ressourcen und Kosten
├── aufgabe.md                     Teilnehmeraufgabe: sechs Versuche mit Vorhersage und Ergebnis
├── trainer.md                     Musterlösung, Diagnoseleiter, Rücknahme, OpenLDAP-Ersatz
├── lab/
│   ├── docker-compose.yml         Lokaler Stack, Projektname keycloak-ad-workshop
│   ├── .env.example               AD_PUBLIC_IP, TEAM
│   ├── realm-import.json          Realm mustertech ohne LDAP-Provider
│   ├── ldap-tools/Dockerfile      Alpine mit openldap-clients
│   ├── ldap-tools/bin/save-secret Passwortdatei ohne Zeilenumbruch anlegen
│   ├── ldap-tools/bin/decode-guid Base64-objectGUID in GUID-Schreibweise
│   ├── certs/.gitkeep             workshop-ca.crt (ignoriert)
│   ├── secrets/.gitkeep           bind.pw, operator.pw (ignoriert)
│   └── ldif/team01..03/           Änderungs- und Rücknahme-LDIFs je Team
├── solution/
│   ├── README.md                  Anwendung der Trainerlösung
│   └── apply-solution.sh          kcadm: Provider, Mapper, Strategie, Suchbasis, Sync
└── scripts/
    ├── lib/Workshop.Common.psm1   gcloud-Wrapper, Manifest, Eigentumsprüfung, IAP-REST
    ├── New-Workshop.ps1           GCP-Ressourcen mit Manifest, -PlanOnly
    ├── Protect-Workshop.ps1       Gast-Account-Manager nach Promotion abschalten
    ├── Initialize-Domain.ps1      Gast: Datenträger, Umbenennung, AD DS, DNS, Zeit
    ├── Initialize-Workshop.ps1    Gast: CA, LDAPS-Zertifikat, OUs, Konten, Delegation
    ├── Reset-Team.ps1             Gast: Ausgangszustand eines Teams
    ├── Test-Workshop.ps1          Trainer- und Gastprüfungen
    ├── Remove-Workshop.ps1        Abbau anhand des Manifests
    └── tests/*.Tests.ps1          Pester-Tests für Modul, PlanOnly und Abbau
```

Lokale, nicht versionierte Laufzeitdaten liegen unter `workshops/active-directory/.run/`
(`manifest.json`, `secrets/`, `report-*.json`).

---

### Task 1: Gerüst, Ignorierregeln und Verweise

**Files:**

- Create: `workshops/active-directory/lab/certs/.gitkeep`, `workshops/active-directory/lab/secrets/.gitkeep`
- Modify: `.gitignore`
- Modify: `workshops/README.md` (Tabelle und Abschnitt "Unterlagen")
- Modify: `workshops/ldap-ad/README.md` (Verweis auf die optionale Tag-3-Einheit)

**Interfaces:**

- Produces: die ignorierten Pfade `lab/.env`, `lab/certs/*.crt`, `lab/secrets/*.pw`, `.run/`

- [ ] **Step 1: Ignorierregeln ergänzen**

Am Ende von `.gitignore`:

```gitignore
# AD-Workshop: lokale Laufzeitdaten, Zertifikat und Geheimnisse
workshops/active-directory/.run/
workshops/active-directory/lab/.env
workshops/active-directory/lab/certs/*
!workshops/active-directory/lab/certs/.gitkeep
workshops/active-directory/lab/secrets/*
!workshops/active-directory/lab/secrets/.gitkeep
```

- [ ] **Step 2: Verweise in `workshops/README.md`**

Tabellenzeile nach "LDAP und Active Directory":

```markdown
| [Active Directory auf GCP](active-directory/README.md) | Modul 06b, Modul 07 mit Lab 07c, Docker | 90 Min. |
```

Neuer Absatz unter "Einsatz im Kurs": Die AD-Einheit ist optional für Tag 3, braucht einen vom Trainer
vorbereiteten Windows-Server auf GCP und fällt bei fehlender Freigabe auf das OpenLDAP-Lab zurück.

- [ ] **Step 3: Verweis in `workshops/ldap-ad/README.md`**

Absatz am Ende von "Vorbereitung": Wer an Tag 3 gegen ein echtes Active Directory arbeiten will,
verwendet die [AD-Einheit](../active-directory/README.md); dort steht auch, wann OpenLDAP der Ersatz bleibt.

- [ ] **Step 4: Prüfen**

Run: `pre-commit run markdownlint-cli2 --files workshops/README.md workshops/ldap-ad/README.md`
Expected: Passed

- [ ] **Step 5: Commit**

```bash
git add .gitignore workshops/README.md workshops/ldap-ad/README.md workshops/active-directory
git commit -m "docs(workshops): reference the Active Directory unit"
```

---

### Task 2: Lokaler Compose-Stack mit LDAP-Werkzeugcontainer

**Files:**

- Create: `workshops/active-directory/lab/docker-compose.yml`
- Create: `workshops/active-directory/lab/.env.example`
- Create: `workshops/active-directory/lab/ldap-tools/Dockerfile`
- Create: `workshops/active-directory/lab/ldap-tools/bin/save-secret`
- Create: `workshops/active-directory/lab/ldap-tools/bin/decode-guid`

**Interfaces:**

- Consumes: `labs/assignments/services/portal-frontend`, `labs/assignments/services/portal-api`
- Produces: Dienste `postgres`, `keycloak`, `setup`, `portal`, `api`, `ldap-tools`; Hosteintrag
  `dc01.ad.mustertech.test` aus `AD_PUBLIC_IP`; Mounts `/certs`, `/secrets`, `/ldif` im Werkzeugcontainer,
  `/workshop/solution` und `/workshop/secrets` in Keycloak.

- [ ] **Step 1: `.env.example`**

```dotenv
# Öffentliche Test-IP des Workshop-DCs aus dem Manifest des Trainers
AD_PUBLIC_IP=203.0.113.10
# Eigene Gruppe: 01, 02 oder 03
TEAM=01
```

- [ ] **Step 2: `docker-compose.yml`**

```yaml
# Keycloak Schulung - Workshop: Active Directory auf GCP
#
# Vorbereiten: cp .env.example .env  (AD_PUBLIC_IP eintragen)
#              CA-Zertifikat nach certs/workshop-ca.crt kopieren
# Starten:     docker compose up -d
# Stoppen:     docker compose down
# Reset:       docker compose down -v && docker compose up -d

name: keycloak-ad-workshop

services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak_db_password
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h 127.0.0.1 -U keycloak -d keycloak"]
      interval: 10s
      timeout: 5s
      retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:26.5.7
    command: start-dev --import-realm
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: admin
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak_db_password
      KC_HOSTNAME: http://localhost:8080
      KC_TRUSTSTORE_PATHS: /opt/keycloak/conf/truststores
    extra_hosts:
      - "dc01.ad.mustertech.test:${AD_PUBLIC_IP:?AD_PUBLIC_IP in .env eintragen}"
    ports:
      - "8080:8080"
    volumes:
      - ./realm-import.json:/opt/keycloak/data/import/realm-import.json:ro
      - ./certs:/opt/keycloak/conf/truststores:ro
      - ../solution:/workshop/solution:ro
      - ./secrets:/workshop/secrets:ro
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "exec 3<>/dev/tcp/127.0.0.1/8080"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 90s

  setup:
    image: quay.io/keycloak/keycloak:26.5.7
    depends_on:
      keycloak:
        condition: service_healthy
    restart: "no"
    entrypoint: /bin/bash
    command:
      - -c
      - |
        set -euo pipefail
        KCADM=/opt/keycloak/bin/kcadm.sh
        $$KCADM config credentials --server http://keycloak:8080 --realm master --user admin --password admin
        $$KCADM update realms/master -s sslRequired=NONE
        $$KCADM update users/profile -r mustertech -s unmanagedAttributePolicy=ADMIN_EDIT
        echo "=== Setup complete ==="

  portal:
    build:
      context: ../../../labs/assignments/services/portal-frontend
    ports:
      - "5173:80"
    depends_on:
      keycloak:
        condition: service_healthy

  api:
    build:
      context: ../../../labs/assignments/services/portal-api
    ports:
      - "3001:3001"
    environment:
      API_PORT: "3001"
      VITE_KEYCLOAK_URL: http://keycloak:8080
      KEYCLOAK_PUBLIC_URL: http://localhost:8080
      VITE_KEYCLOAK_REALM: mustertech
    depends_on:
      keycloak:
        condition: service_healthy

  ldap-tools:
    build:
      context: ./ldap-tools
    init: true
    environment:
      LDAPTLS_CACERT: /certs/workshop-ca.crt
      LDAPTLS_REQCERT: demand
      TEAM: ${TEAM:-01}
    extra_hosts:
      - "dc01.ad.mustertech.test:${AD_PUBLIC_IP:?AD_PUBLIC_IP in .env eintragen}"
    volumes:
      - ./certs:/certs:ro
      - ./secrets:/secrets
      - ./ldif:/ldif:ro

volumes:
  postgres-data:
```

`KC_TRUSTSTORE_PATHS` zeigt auf das Verzeichnis, damit ein fehlendes Zertifikat den Start nicht
verhindert. Ob Keycloak 26.5.7 das `.gitkeep` toleriert, prüft Step 6; sonst auf den Dateipfad umstellen.

- [ ] **Step 3: `ldap-tools/Dockerfile`**

```dockerfile
FROM alpine:3.22
RUN apk add --no-cache openldap-clients ca-certificates coreutils
COPY bin/save-secret bin/decode-guid /usr/local/bin/
RUN chmod 0755 /usr/local/bin/save-secret /usr/local/bin/decode-guid
WORKDIR /ldif
CMD ["sleep", "infinity"]
```

- [ ] **Step 4: Hilfsskripte**

`bin/save-secret`:

```sh
#!/bin/sh
# Legt /secrets/<name>.pw ohne Zeilenumbruch an, damit ldapsearch -y die Datei direkt verwenden kann.
set -e
name="$1"
if [ -z "$name" ]; then
  echo "Aufruf: save-secret <bind|operator>" >&2
  exit 2
fi
printf 'Passwort fuer %s: ' "$name"
stty -echo
read -r pw
stty echo
echo
printf '%s' "$pw" > "/secrets/$name.pw"
chmod 0600 "/secrets/$name.pw"
echo "gespeichert: /secrets/$name.pw"
```

`bin/decode-guid`:

```sh
#!/bin/sh
# Wandelt ein Base64-kodiertes objectGUID (ldapsearch: "objectGUID:: ...") in die GUID-Schreibweise,
# die Keycloak im Attribut LDAP_ID zeigt. AD speichert die ersten drei Blöcke in umgekehrter Byte-Reihenfolge.
set -e
b64="${1:-$(cat)}"
hex=$(printf '%s' "$b64" | base64 -d | od -An -tx1 -v | tr -d ' \n')
if [ ${#hex} -ne 32 ]; then
  echo "kein 16-Byte-Wert: $b64" >&2
  exit 1
fi
p() { printf '%s' "$hex" | cut -c"$1"; }
printf '%s%s%s%s-%s%s-%s%s-%s-%s\n' \
  "$(p 7-8)" "$(p 5-6)" "$(p 3-4)" "$(p 1-2)" \
  "$(p 11-12)" "$(p 9-10)" "$(p 15-16)" "$(p 13-14)" \
  "$(p 17-20)" "$(p 21-32)"
```

- [ ] **Step 5: Konfiguration prüfen**

Run: `cd workshops/active-directory/lab && cp .env.example .env && docker compose config --quiet && echo ok`
Expected: `ok`

- [ ] **Step 6: Stack hochfahren (ohne AD, mit Test-IP)**

Run:

```bash
cd workshops/active-directory/lab
docker compose up -d --build
docker compose ps
docker compose logs setup | tail -3
docker compose exec ldap-tools sh -c 'printf "AQIDBAUGBwgJCgsMDQ4PEA==" | decode-guid'
```

Expected: `postgres`, `keycloak`, `portal`, `api`, `ldap-tools` laufen, `setup` mit Exit 0 und
"=== Setup complete ===", GUID `04030201-0605-0807-090a-0b0c0d0e0f10`.
Die Realm-Datei aus Task 3 ist dafür nötig; bis dahin genügt ein Start ohne Import-Fehler mit dem Realm aus Task 3.

- [ ] **Step 7: Abbauen**

Run: `docker compose down -v && docker volume ls --format '{{.Name}}' | grep keycloak-ad-workshop || echo clean`
Expected: `clean`

- [ ] **Step 8: Commit**

```bash
git add workshops/active-directory/lab
git commit -m "feat(workshops): add local stack for the Active Directory unit"
```

---

### Task 3: Realm-Import ohne LDAP-Provider

**Files:**

- Create: `workshops/active-directory/lab/realm-import.json`

**Interfaces:**

- Consumes: `labs/assignments/modul-06b-client-management/realm-import.json` als Vorlage
- Produces: Realm `mustertech` mit Rollen `mitarbeiter`, `manager`, `admin`; Gruppen `Mitarbeiter`
  (Rolle `mitarbeiter`), `Teamleitung` (keine Rolle), `Manager` (Rolle `manager`); Clients `portal-frontend`
  (public, PKCE S256, Direct Grant, Audience-Mapper auf `portal-api`) und `portal-api` (bearer-only);
  lokaler Benutzer `max.admin`/`test1234` mit Rolle `admin`; `accessTokenLifespan` 120.

- [ ] **Step 1: Datei aus der 06b-Vorlage ableiten**

```bash
jq '
  .accessTokenLifespan = 120
  | .users = [ .users[] | select(.username == "max.admin") | .groups = [] ]
  | .groups = [
      {name: "Mitarbeiter", path: "/Mitarbeiter", realmRoles: ["mitarbeiter"], attributes: {}, subGroups: []},
      {name: "Teamleitung", path: "/Teamleitung", realmRoles: [], attributes: {}, subGroups: []},
      {name: "Manager", path: "/Manager", realmRoles: ["manager"], attributes: {}, subGroups: []}
    ]
  | .clients += [{
      clientId: "portal-api", name: "Portal API", enabled: true, bearerOnly: true,
      publicClient: false, standardFlowEnabled: false, directAccessGrantsEnabled: false,
      protocol: "openid-connect", attributes: {}
    }]
  | (.clients[] | select(.clientId == "portal-frontend") | .protocolMappers) += [{
      name: "portal-api-audience", protocol: "openid-connect",
      protocolMapper: "oidc-audience-mapper",
      config: {"included.client.audience": "portal-api", "id.token.claim": "false",
               "access.token.claim": "true", "introspection.token.claim": "true"}
    }]
' labs/assignments/modul-06b-client-management/realm-import.json \
  > workshops/active-directory/lab/realm-import.json
```

Danach die Datei lesen: Rollenbeschreibungen bleiben, `max.admin` behält Rolle `admin`, keine
Gruppenzuordnung auf `Management`. Die Rollennamen `entwicklung`/`vertrieb` dürfen nicht auftauchen.

- [ ] **Step 2: Stack starten und Token prüfen**

```bash
cd workshops/active-directory/lab && docker compose up -d --build
# warten bis setup "Setup complete" meldet
TOKEN=$(curl -s -X POST http://localhost:8080/realms/mustertech/protocol/openid-connect/token \
  -d client_id=portal-frontend -d grant_type=password -d username=max.admin -d password=test1234 \
  -d scope=openid | jq -r .access_token)
echo "$TOKEN" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq '{aud, realm_access, exp, iat}'
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" http://localhost:3001/api/profile
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" http://localhost:3001/api/urlaubsantraege
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3001/api/urlaubsantraege
```

Expected: `aud` enthält `portal-api`, `exp - iat == 120`, Statuscodes `200`, `403`, `401`.
Im Browser: <http://localhost:5173>, Login `max.admin`, "Mein Profil" liefert Rollen.

- [ ] **Step 3: Abbauen und committen**

```bash
docker compose down -v
git add workshops/active-directory/lab/realm-import.json
git commit -m "feat(workshops): prepare the mustertech realm for the AD unit"
```

---

### Task 4: LDIF-Dateien je Team

**Files:**

- Create: `workshops/active-directory/lab/ldif/team01/01-hans-nach-moved.ldif` und fünf weitere
- Create: dieselben sechs Dateien unter `team02/` und `team03/`

**Interfaces:**

- Produces: Dateipfade `/ldif/team<NN>/<Datei>` im Werkzeugcontainer; Reihenfolge 01 bis 06 entspricht
  dem Ablauf in `aufgabe.md`.

- [ ] **Step 1: Team01 anlegen**

`01-hans-nach-moved.ldif`:

```ldif
# Versuch 4: Hans von OU=Users nach OU=Moved verschieben. DN ändert sich, objectGUID bleibt.
dn: CN=Hans Mueller,OU=Users,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test
changetype: modrdn
newrdn: CN=Hans Mueller
deleteoldrdn: 1
newsuperior: OU=Moved,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test
```

`02-anna-aus-teamleitung.ldif`:

```ldif
# Versuch 5: Anna verliert die indirekte Managerzuordnung.
dn: CN=Teamleitung,OU=Groups,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test
changetype: modify
delete: member
member: CN=Anna Schmidt,OU=Users,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test
```

`03-hans-deaktivieren.ldif` (Hans liegt zu diesem Zeitpunkt in `OU=Moved`; 66048 = NORMAL_ACCOUNT +
DONT_EXPIRE_PASSWORD, 66050 zusätzlich ACCOUNTDISABLE):

```ldif
# Versuch 5: Konto deaktivieren. Vorher den aktuellen Wert von userAccountControl lesen.
dn: CN=Hans Mueller,OU=Moved,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test
changetype: modify
replace: userAccountControl
userAccountControl: 66050
```

`04-hans-aktivieren.ldif`: wie 03 mit Wert `66048`.

`05-anna-in-teamleitung.ldif`: wie 02 mit `add: member`.

`06-hans-zurueck-nach-users.ldif`:

```ldif
# Versuch 6: Rücknahme des OU-Wechsels.
dn: CN=Hans Mueller,OU=Moved,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test
changetype: modrdn
newrdn: CN=Hans Mueller
deleteoldrdn: 1
newsuperior: OU=Users,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test
```

- [ ] **Step 2: Team02 und Team03 ableiten**

```bash
cd workshops/active-directory/lab/ldif
for t in 02 03; do mkdir -p team$t; for f in team01/*.ldif; do
  sed "s/Team01/Team$t/g; s/t01\./t$t./g" "$f" > "team$t/$(basename "$f")"; done; done
grep -rl 'Team01' team02 team03 && echo FEHLER || echo ok
```

Expected: `ok`

- [ ] **Step 3: Syntaxprüfung**

Run: `docker run --rm -v "$PWD:/ldif:ro" alpine:3.22 sh -c 'apk add -q openldap-clients && for f in /ldif/team*/*.ldif; do ldapmodify -n -H ldap://127.0.0.1:1 -f "$f" >/dev/null 2>&1 || echo "$f"; done; echo done'`

`ldapmodify -n` parst ohne Verbindung; Expected: nur `done`.

- [ ] **Step 4: Commit**

```bash
git add workshops/active-directory/lab/ldif
git commit -m "feat(workshops): add per-team LDIF changes for the AD unit"
```

---

### Task 5: PowerShell-Modul `Workshop.Common`

**Files:**

- Create: `workshops/active-directory/scripts/lib/Workshop.Common.psm1`
- Test: `workshops/active-directory/scripts/tests/Workshop.Common.Tests.ps1`

**Interfaces:**

- Produces:
  - `Invoke-GcloudRaw([string[]]$Arguments) : string` führt gcloud aus, wirft bei Exit-Code ungleich 0
    mit stderr. Wird in Tests gemockt.
  - `Get-GcloudJson([string[]]$Arguments, [switch]$IgnoreNotFound) : object` hängt `--format=json` an.
  - `Invoke-GcloudChange([string[]]$Arguments, [string]$Description) : object` läuft nur außerhalb
    von PlanOnly; sonst wird `$Description` in der Planliste gesammelt.
  - `Enable-WorkshopPlanOnly()`, `Test-WorkshopPlanOnly() : bool`, `Get-WorkshopPlannedChanges() : string[]`.
  - `New-WorkshopManifest(...)`, `Read-WorkshopManifest($Path)`, `Save-WorkshopManifest($Manifest, $Path)`.
  - `Get-WorkshopResourceNames($Prefix) : hashtable` mit Schlüsseln `Network`, `Subnet`, `FirewallLdaps`,
    `FirewallIapRdp`, `InternalAddress`, `ExternalAddress`, `DataDisk`, `Instance`, `BootDisk`, `NetworkTag`.
  - `Test-WorkshopOwnedResource($Resource, $RunId) : bool` prüft Labels `workshop=keycloak-ad` und
    `run-id=<RunId>` oder die Beschreibung `keycloak-ad-workshop run-id=<RunId>`.
  - `Get-IapTunnelPolicy($ProjectNumber, $Zone, $InstanceId)`, `Set-IapTunnelPolicy(..., $Policy)` über
    `Invoke-IapApi($Method, $Url, $Body)` (REST, Token aus `gcloud auth print-access-token`).
  - `Write-WorkshopStep([string]$Text)`.

- [ ] **Step 1: Tests schreiben**

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../lib/Workshop.Common.psm1" -Force
}

Describe 'Get-WorkshopResourceNames' {
    It 'derives every name from the prefix' {
        $n = Get-WorkshopResourceNames -Prefix 'kcad'
        $n.Network | Should -Be 'kcad-vpc'
        $n.Subnet | Should -Be 'kcad-subnet'
        $n.FirewallLdaps | Should -Be 'kcad-allow-ldaps'
        $n.FirewallIapRdp | Should -Be 'kcad-allow-iap-rdp'
        $n.InternalAddress | Should -Be 'kcad-dc01-internal'
        $n.ExternalAddress | Should -Be 'kcad-dc01-external'
        $n.DataDisk | Should -Be 'kcad-dc01-data'
        $n.Instance | Should -Be 'kcad-dc01'
        $n.BootDisk | Should -Be 'kcad-dc01'
        $n.NetworkTag | Should -Be 'kcad-dc'
    }
}

Describe 'Test-WorkshopOwnedResource' {
    It 'accepts matching labels' {
        $r = [pscustomobject]@{ labels = [pscustomobject]@{ workshop = 'keycloak-ad'; 'run-id' = '20260915-1200' } }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeTrue
    }
    It 'accepts a matching description' {
        $r = [pscustomobject]@{ description = 'keycloak-ad-workshop run-id=20260915-1200' }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeTrue
    }
    It 'rejects foreign resources' {
        $r = [pscustomobject]@{ name = 'kcad-vpc'; labels = [pscustomobject]@{ workshop = 'other' } }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeFalse
    }
    It 'rejects another run id' {
        $r = [pscustomobject]@{ description = 'keycloak-ad-workshop run-id=20260101-0000' }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeFalse
    }
}

Describe 'Invoke-GcloudChange' {
    BeforeEach { Reset-WorkshopPlanState }
    It 'records instead of executing in plan mode' {
        Mock Invoke-GcloudRaw { throw 'must not run' } -ModuleName Workshop.Common
        Enable-WorkshopPlanOnly
        $r = Invoke-GcloudChange -Arguments @('compute', 'networks', 'create', 'x') -Description 'create network x'
        $r | Should -BeNullOrEmpty
        (Get-WorkshopPlannedChanges) | Should -Contain 'create network x'
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0
    }
    It 'executes with --quiet and --format=json otherwise' {
        Mock Invoke-GcloudRaw { '{"name":"x"}' } -ModuleName Workshop.Common
        $r = Invoke-GcloudChange -Arguments @('compute', 'networks', 'create', 'x') -Description 'create'
        $r.name | Should -Be 'x'
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 1 -ParameterFilter {
            $Arguments -contains '--quiet' -and $Arguments -contains '--format=json'
        }
    }
}

Describe 'Get-GcloudJson' {
    It 'returns null for not found when requested' {
        Mock Invoke-GcloudRaw { throw 'ERROR: (gcloud.compute.networks.describe) Could not fetch resource: - The resource was not found' } -ModuleName Workshop.Common
        Get-GcloudJson -Arguments @('compute', 'networks', 'describe', 'x') -IgnoreNotFound | Should -BeNullOrEmpty
    }
    It 'rethrows other errors' {
        Mock Invoke-GcloudRaw { throw 'ERROR: PERMISSION_DENIED' } -ModuleName Workshop.Common
        { Get-GcloudJson -Arguments @('compute', 'networks', 'describe', 'x') -IgnoreNotFound } | Should -Throw '*PERMISSION_DENIED*'
    }
}

Describe 'Manifest' {
    It 'round-trips through JSON' {
        $path = Join-Path $TestDrive 'manifest.json'
        $m = New-WorkshopManifest -ProjectId 'p' -ProjectNumber '1' -Region 'europe-west3' -Zone 'europe-west3-a' -Prefix 'kcad' -RunId '20260915-1200' -ExpiresAt ([datetime]'2026-09-17T12:00:00Z')
        $m.resources['network'] = @{ name = 'kcad-vpc'; selfLink = 'https://example/x'; createdAt = '2026-09-15T12:00:00Z' }
        Save-WorkshopManifest -Manifest $m -Path $path
        $back = Read-WorkshopManifest -Path $path
        $back.projectId | Should -Be 'p'
        $back.resources.network.selfLink | Should -Be 'https://example/x'
        $back.runId | Should -Be '20260915-1200'
    }
    It 'refuses a manifest without project number' {
        $path = Join-Path $TestDrive 'bad.json'
        '{"projectId":"p"}' | Set-Content $path
        { Read-WorkshopManifest -Path $path } | Should -Throw '*projectNumber*'
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag sehen**

Run: `pwsh -NoProfile -Command "Invoke-Pester workshops/active-directory/scripts/tests/Workshop.Common.Tests.ps1 -Output Detailed"`
Expected: Fehler, Modul nicht gefunden.

- [ ] **Step 3: Modul schreiben**

```powershell
Set-StrictMode -Version Latest

$script:PlanOnly = $false
$script:PlannedChanges = [System.Collections.Generic.List[string]]::new()
$script:WorkshopLabel = 'keycloak-ad'

function Write-WorkshopStep {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Reset-WorkshopPlanState {
    $script:PlanOnly = $false
    $script:PlannedChanges.Clear()
}

function Enable-WorkshopPlanOnly { $script:PlanOnly = $true }
function Test-WorkshopPlanOnly { return $script:PlanOnly }
function Get-WorkshopPlannedChanges { return @($script:PlannedChanges) }

function Invoke-GcloudRaw {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $stderr = [System.IO.Path]::GetTempFileName()
    try {
        $stdout = & gcloud @Arguments 2> $stderr
        if ($LASTEXITCODE -ne 0) {
            throw ("gcloud {0} failed: {1}" -f ($Arguments -join ' '), (Get-Content $stderr -Raw))
        }
        return ($stdout -join "`n")
    } finally {
        Remove-Item $stderr -ErrorAction SilentlyContinue
    }
}

function Get-GcloudJson {
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$IgnoreNotFound)
    try {
        $raw = Invoke-GcloudRaw -Arguments ($Arguments + '--format=json')
    } catch {
        if ($IgnoreNotFound -and $_.Exception.Message -match 'was not found|NOT_FOUND|HTTPError 404') { return $null }
        throw
    }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
}

function Invoke-GcloudChange {
    param([Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$Description)
    if ($script:PlanOnly) {
        $script:PlannedChanges.Add($Description)
        Write-Host "[plan] $Description" -ForegroundColor Yellow
        return $null
    }
    Write-WorkshopStep $Description
    $raw = Invoke-GcloudRaw -Arguments ($Arguments + @('--quiet', '--format=json'))
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
}

function Get-WorkshopResourceNames {
    param([Parameter(Mandatory)][string]$Prefix)
    return @{
        Network         = "$Prefix-vpc"
        Subnet          = "$Prefix-subnet"
        FirewallLdaps   = "$Prefix-allow-ldaps"
        FirewallIapRdp  = "$Prefix-allow-iap-rdp"
        InternalAddress = "$Prefix-dc01-internal"
        ExternalAddress = "$Prefix-dc01-external"
        DataDisk        = "$Prefix-dc01-data"
        Instance        = "$Prefix-dc01"
        BootDisk        = "$Prefix-dc01"
        NetworkTag      = "$Prefix-dc"
    }
}

function Test-WorkshopOwnedResource {
    param([Parameter(Mandatory)]$Resource, [Parameter(Mandatory)][string]$RunId)
    $labels = $Resource.PSObject.Properties['labels']
    if ($labels -and $labels.Value) {
        $l = $labels.Value
        $w = $l.PSObject.Properties['workshop']; $r = $l.PSObject.Properties['run-id']
        if ($w -and $r -and $w.Value -eq $script:WorkshopLabel -and $r.Value -eq $RunId) { return $true }
    }
    $desc = $Resource.PSObject.Properties['description']
    if ($desc -and $desc.Value -eq "keycloak-ad-workshop run-id=$RunId") { return $true }
    return $false
}

function New-WorkshopManifest {
    param(
        [Parameter(Mandatory)][string]$ProjectId, [Parameter(Mandatory)][string]$ProjectNumber,
        [Parameter(Mandatory)][string]$Region, [Parameter(Mandatory)][string]$Zone,
        [Parameter(Mandatory)][string]$Prefix, [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][datetime]$ExpiresAt
    )
    return [ordered]@{
        schema        = 1
        status        = 'creating'
        projectId     = $ProjectId
        projectNumber = $ProjectNumber
        region        = $Region
        zone          = $Zone
        prefix        = $Prefix
        runId         = $RunId
        createdAt     = (Get-Date).ToUniversalTime().ToString('o')
        expiresAt     = $ExpiresAt.ToUniversalTime().ToString('o')
        versions      = [ordered]@{}
        network       = [ordered]@{}
        resources     = [ordered]@{}
        iamBindings   = @()
        domain        = [ordered]@{}
        removed       = [ordered]@{}
    }
}

function Save-WorkshopManifest {
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $Manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $Path -Encoding utf8
}

function Read-WorkshopManifest {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { throw "Manifest nicht gefunden: $Path" }
    $m = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
    foreach ($k in 'projectId', 'projectNumber', 'zone', 'region', 'runId', 'prefix') {
        if (-not $m.ContainsKey($k) -or [string]::IsNullOrWhiteSpace([string]$m[$k])) { throw "Manifest ohne $k" }
    }
    return $m
}

function Invoke-IapApi {
    param([Parameter(Mandatory)][string]$Method, [Parameter(Mandatory)][string]$Url, $Body)
    $token = (Invoke-GcloudRaw -Arguments @('auth', 'print-access-token')).Trim()
    $headers = @{ Authorization = "Bearer $token" }
    if ($null -ne $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 10)
    }
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
}

function Get-IapTunnelResourceUrl {
    param([Parameter(Mandatory)][string]$ProjectNumber, [Parameter(Mandatory)][string]$Zone, [Parameter(Mandatory)][string]$InstanceId)
    return "https://iap.googleapis.com/v1/projects/$ProjectNumber/iap_tunnel/zones/$Zone/instances/$InstanceId"
}

function Get-IapTunnelPolicy {
    param([Parameter(Mandatory)][string]$ProjectNumber, [Parameter(Mandatory)][string]$Zone, [Parameter(Mandatory)][string]$InstanceId)
    $url = (Get-IapTunnelResourceUrl -ProjectNumber $ProjectNumber -Zone $Zone -InstanceId $InstanceId) + ':getIamPolicy'
    return Invoke-IapApi -Method Post -Url $url -Body @{ options = @{ requestedPolicyVersion = 3 } }
}

function Set-IapTunnelPolicy {
    param([Parameter(Mandatory)][string]$ProjectNumber, [Parameter(Mandatory)][string]$Zone, [Parameter(Mandatory)][string]$InstanceId, [Parameter(Mandatory)]$Policy)
    $url = (Get-IapTunnelResourceUrl -ProjectNumber $ProjectNumber -Zone $Zone -InstanceId $InstanceId) + ':setIamPolicy'
    return Invoke-IapApi -Method Post -Url $url -Body @{ policy = $Policy }
}

Export-ModuleMember -Function *
```

- [ ] **Step 4: Tests grün**

Run: `pwsh -NoProfile -Command "Invoke-Pester workshops/active-directory/scripts/tests/Workshop.Common.Tests.ps1 -Output Detailed"`
Expected: alle Tests Passed.

- [ ] **Step 5: Analyzer und Commit**

Run: `pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path workshops/active-directory/scripts -Recurse -Severity Warning,Error"`
Expected: keine Ausgabe.

```bash
git add workshops/active-directory/scripts
git commit -m "feat(workshops): add gcloud and manifest helpers for the AD unit"
```

---

### Task 6: `New-Workshop.ps1` mit PlanOnly und Manifest

**Files:**

- Create: `workshops/active-directory/scripts/New-Workshop.ps1`
- Test: `workshops/active-directory/scripts/tests/New-Workshop.Tests.ps1`

**Interfaces:**

- Consumes: alle Funktionen aus Task 5.
- Produces: `.run/manifest.json` (Schema aus Task 5) mit `resources.<key>` = `{name, selfLink, createdAt,
  zone|region}`, `network.internalIp`, `network.externalIp`, `network.ldapsSourceRanges`,
  `versions.image`, `versions.gcloud`, `iamBindings[]` = `{principal, role, condition, resource}`;
  `.run/secrets/wsadmin.json` mit dem einmaligen Administratorpasswort (Berechtigung 600).

Parameter:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')][string]$ProjectId,
    [ValidatePattern('^[a-z]+-[a-z]+\d$')][string]$Region = 'europe-west3',
    [ValidatePattern('^[a-z]+-[a-z]+\d-[a-z]$')][string]$Zone = 'europe-west3-a',
    [ValidatePattern('^[a-z][a-z0-9]{2,11}$')][string]$Prefix = 'kcad',
    [Parameter(Mandatory)][string[]]$LdapsSourceRanges,
    [Parameter(Mandatory)][ValidatePattern('^(user|group|serviceAccount):.+@.+$')][string]$TrainerPrincipal,
    [Parameter(Mandatory)][datetime]$ExpiresAt,
    [string]$MachineType = 'e2-standard-2',
    [int]$BootDiskGb = 64,
    [int]$DataDiskGb = 20,
    [string]$SubnetRange = '10.80.0.0/24',
    [string]$InternalIp = '10.80.0.10',
    [string]$AdminUser = 'wsadmin',
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..' '.run' 'manifest.json'),
    [switch]$PlanOnly
)
```

Ablauf des Skripts:

1. Eingaben prüfen: Zone beginnt mit Region; jede Quell-IP ist ein IPv4-CIDR ohne `0.0.0.0/0` und mit
   Präfixlänge ≥ 24; `ExpiresAt` liegt in der Zukunft und höchstens 48 Stunden entfernt; `InternalIp` liegt
   im `SubnetRange`.
2. Vorprüfung nur lesend: `projects describe` (Nummer), `billing projects describe` (`billingEnabled`),
   `services list --enabled` (compute, iap), `compute images describe-from-family windows-2022
   --project=windows-cloud` (Name), `compute machine-types describe`, `compute regions describe` (Quota
   `CPUS`, `IN_USE_ADDRESSES`, `STATIC_ADDRESSES`), `gcloud version`. Fehlende APIs oder Billing:
   Abbruch mit Nennung, keine Aktivierung.
3. Manifest laden, falls vorhanden und `status` nicht `removed`: gleiche Projekt-ID, Zone und Präfix
   nötig, sonst Abbruch. Sonst neues Manifest mit `runId = yyyyMMdd-HHmm`.
4. Für jede Ressource: `describe` mit `-IgnoreNotFound`. Vorhanden und Eigentum nachgewiesen: übernehmen.
   Vorhanden ohne Nachweis: Abbruch. Fehlend: in Planliste beziehungsweise erstellen.
5. Erstellen in dieser Reihenfolge, nach jedem Schritt Manifest speichern:
   - `compute networks create <vpc> --subnet-mode=custom --description="keycloak-ad-workshop run-id=<id>"`
   - `compute networks subnets create <subnet> --network=<vpc> --region --range=<SubnetRange>
     --description=...`
   - `compute firewall-rules create <allow-ldaps> --network=<vpc> --direction=INGRESS --action=ALLOW
     --rules=tcp:636 --source-ranges=<ranges> --target-tags=<tag> --description=...`
   - `compute firewall-rules create <allow-iap-rdp> ... --rules=tcp:3389 --source-ranges=35.235.240.0/20
     --target-tags=<tag> --description=...`
   - `compute addresses create <internal> --region --subnet=<subnet> --addresses=<InternalIp>
     --description=... --labels=workshop=keycloak-ad,run-id=<id>`
   - `compute addresses create <external> --region --network-tier=PREMIUM --description=... --labels=...`
   - `compute disks create <data> --zone --size=<DataDiskGb>GB --type=pd-balanced --labels=...`
   - `compute instances create <instance> --zone --machine-type --image=<name> --image-project=windows-cloud
     --boot-disk-size=<BootDiskGb>GB --boot-disk-type=pd-balanced --boot-disk-device-name=<instance>
     --disk=name=<data>,device-name=adds-data,mode=rw,boot=no
     --network-interface=subnet=<subnet>,private-network-ip=<InternalIp>,address=<externalAddressName>
     --tags=<tag> --no-service-account --no-scopes --shielded-secure-boot --shielded-vtpm
     --shielded-integrity-monitoring --labels=workshop=keycloak-ad,run-id=<id>
     --metadata=enable-oslogin=FALSE --description=...`
   - IAP-Bindung: `Get-IapTunnelPolicy`, Binding `{role: roles/iap.tunnelResourceAccessor,
     members: [<TrainerPrincipal>], condition: {title: 'keycloak-ad-workshop rdp', expression:
     'destination.port == 3389'}}` ergänzen, `version = 3`, `Set-IapTunnelPolicy`. In PlanOnly nur listen.
     Bei HTTP 403: Fehler mit Hinweis auf fehlende IAP-Adminrechte, Manifest bleibt gültig.
6. Warten bis Serial-Port-Ausgabe (`compute instances get-serial-port-output`) die Zeile
   `Instance setup finished` enthält (Timeout 15 Minuten), danach
   `compute reset-windows-password <instance> --zone --user=<AdminUser>` (Mutation) und das Ergebnis nach
   `.run/secrets/wsadmin.json` (chmod 600) schreiben. Keine Ausgabe des Passworts im Manifest oder Log.
7. `status = 'created'`, Zusammenfassung ausgeben: interne/externe IP, Image, nächste Schritte
   (`gcloud compute start-iap-tunnel <instance> 3389 --local-host-port=localhost:33389 --zone --project`).

- [ ] **Step 1: Tests schreiben**

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../lib/Workshop.Common.psm1" -Force
    $script:Script = "$PSScriptRoot/../New-Workshop.ps1"
    $script:Common = @{
        ProjectId = 'demo-project'; LdapsSourceRanges = @('203.0.113.0/24'); TrainerPrincipal = 'user:trainer@example.org'
        ExpiresAt = (Get-Date).AddHours(24); ManifestPath = (Join-Path $TestDrive 'manifest.json')
    }
    function script:MockReads {
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            switch -Regex ($a) {
                '^projects describe' { return '{"projectId":"demo-project","projectNumber":"123"}' }
                '^billing projects describe' { return '{"billingEnabled":true,"billingAccountName":"billingAccounts/x"}' }
                '^services list' { return '[{"config":{"name":"compute.googleapis.com"}},{"config":{"name":"iap.googleapis.com"}}]' }
                'images describe-from-family' { return '{"name":"windows-server-2022-dc-v20260909","selfLink":"https://x/img"}' }
                'machine-types describe' { return '{"name":"e2-standard-2","guestCpus":2,"memoryMb":8192}' }
                'regions describe' { return '{"quotas":[{"metric":"CPUS","limit":24,"usage":0},{"metric":"IN_USE_ADDRESSES","limit":8,"usage":0},{"metric":"STATIC_ADDRESSES","limit":8,"usage":0}]}' }
                '^version' { return '{"Google Cloud SDK":"565.0.0"}' }
                'describe' { throw 'ERROR: The resource was not found' }
                default { throw "unexpected gcloud call in plan mode: $a" }
            }
        }
    }
}

Describe 'New-Workshop -PlanOnly' {
    It 'issues no mutating gcloud call and writes no manifest' {
        MockReads
        Mock Invoke-IapApi -ModuleName Workshop.Common { throw 'must not call IAP' }
        & $Script @Common -PlanOnly | Out-Null
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter {
            ($Arguments -join ' ') -match '\b(create|delete|add-metadata|reset-windows-password|add-iam-policy-binding|enable)\b'
        }
        Should -Invoke Invoke-IapApi -ModuleName Workshop.Common -Times 0
        Test-Path $Common.ManifestPath | Should -BeFalse
    }
    It 'rejects 0.0.0.0/0 as LDAPS source' {
        MockReads
        { & $Script @Common -LdapsSourceRanges @('0.0.0.0/0') -PlanOnly } | Should -Throw '*0.0.0.0/0*'
    }
    It 'rejects an expiry beyond 48 hours' {
        MockReads
        { & $Script @Common -ExpiresAt (Get-Date).AddHours(72) -PlanOnly } | Should -Throw '*48*'
    }
    It 'rejects a zone outside the region' {
        MockReads
        { & $Script @Common -Region 'europe-west3' -Zone 'europe-west1-b' -PlanOnly } | Should -Throw '*Zone*'
    }
    It 'aborts when a same-named resource exists without ownership' {
        MockReads
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            if (($Arguments -join ' ') -match 'networks describe') { return '{"name":"kcad-vpc","description":"someone else","selfLink":"https://x/vpc"}' }
            if (($Arguments -join ' ') -match '^projects describe') { return '{"projectId":"demo-project","projectNumber":"123"}' }
            if (($Arguments -join ' ') -match '^billing') { return '{"billingEnabled":true}' }
            if (($Arguments -join ' ') -match '^services list') { return '[{"config":{"name":"compute.googleapis.com"}},{"config":{"name":"iap.googleapis.com"}}]' }
            if (($Arguments -join ' ') -match 'images describe-from-family') { return '{"name":"img"}' }
            if (($Arguments -join ' ') -match 'machine-types describe') { return '{"name":"e2-standard-2"}' }
            if (($Arguments -join ' ') -match 'regions describe') { return '{"quotas":[]}' }
            if (($Arguments -join ' ') -match '^version') { return '{}' }
            throw 'ERROR: The resource was not found'
        }
        { & $Script @Common -PlanOnly } | Should -Throw '*kcad-vpc*'
    }
    It 'aborts when the compute API is missing' {
        MockReads
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common { return '[]' } -ParameterFilter { ($Arguments -join ' ') -match '^services list' }
        { & $Script @Script @Common -PlanOnly } | Should -Throw '*compute.googleapis.com*'
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag sehen**

Run: `pwsh -NoProfile -Command "Invoke-Pester workshops/active-directory/scripts/tests/New-Workshop.Tests.ps1 -Output Detailed"`
Expected: Skript fehlt.

- [ ] **Step 3: Skript schreiben**

Implementierung nach dem Ablauf oben. Kernfunktionen im Skript:

```powershell
function Test-Cidr {
    param([string]$Cidr)
    if ($Cidr -notmatch '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$') { return $false }
    $octets = $Matches[1..4] | ForEach-Object { [int]$_ }
    if ($octets | Where-Object { $_ -gt 255 }) { return $false }
    return ([int]$Matches[5] -le 32)
}

function Get-OrPlanResource {
    param([string]$Key, [string[]]$DescribeArgs, [string[]]$CreateArgs, [string]$Description, [string]$Scope)
    $existing = Get-GcloudJson -Arguments $DescribeArgs -IgnoreNotFound
    if ($null -ne $existing) {
        if (-not (Test-WorkshopOwnedResource -Resource $existing -RunId $manifest.runId)) {
            throw "Ressource $($existing.name) existiert bereits ohne Eigentumsnachweis fuer run-id $($manifest.runId). Abbruch."
        }
        Write-WorkshopStep "$Key vorhanden: $($existing.name)"
        $manifest.resources[$Key] = [ordered]@{ name = $existing.name; selfLink = $existing.selfLink; scope = $Scope; createdAt = $existing.creationTimestamp }
        return $existing
    }
    $created = Invoke-GcloudChange -Arguments $CreateArgs -Description $Description
    if (Test-WorkshopPlanOnly) { return $null }
    $obj = if ($created -is [array]) { $created[0] } else { $created }
    $manifest.resources[$Key] = [ordered]@{ name = $obj.name; selfLink = $obj.selfLink; scope = $Scope; createdAt = (Get-Date).ToUniversalTime().ToString('o') }
    Save-WorkshopManifest -Manifest $manifest -Path $ManifestPath
    return $obj
}
```

Für die Existenzprüfung wird im Fall "vorhanden ohne Nachweis" zuerst die gesamte Liste geprüft und erst
danach erstellt, damit ein Abbruch keine halbfertigen Ressourcen hinterlässt.
`describe`-Aufrufe: `compute networks describe <n> --project`, `compute networks subnets describe <n>
--region --project`, `compute firewall-rules describe <n> --project`, `compute addresses describe <n>
--region --project`, `compute disks describe <n> --zone --project`, `compute instances describe <n> --zone
--project`. Jedes `create` liefert mit `--format=json` das erstellte Objekt.

- [ ] **Step 4: Tests grün, Analyzer, Commit**

Run: Pester wie oben, dann `Invoke-ScriptAnalyzer -Path workshops/active-directory/scripts -Recurse -Severity Warning,Error`
Expected: Passed, keine Analyzer-Ausgabe.

```bash
git add workshops/active-directory/scripts
git commit -m "feat(workshops): provision the AD workshop DC with gcloud"
```

---

### Task 7: `Protect-Workshop.ps1`

**Files:**

- Create: `workshops/active-directory/scripts/Protect-Workshop.ps1`
- Test: `workshops/active-directory/scripts/tests/Protect-Workshop.Tests.ps1`

**Interfaces:**

- Consumes: Manifest aus Task 6.
- Produces: Instanz-Metadaten `disable-account-manager=true`; Manifest `domain.accountManagerDisabledAt`.

```powershell
[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..' '.run' 'manifest.json'),
    [switch]$PlanOnly
)
Import-Module (Join-Path $PSScriptRoot 'lib' 'Workshop.Common.psm1') -Force
if ($PlanOnly) { Enable-WorkshopPlanOnly }
$m = Read-WorkshopManifest -Path $ManifestPath
$inst = Get-GcloudJson -Arguments @('compute', 'instances', 'describe', $m.resources.instance.name, "--zone=$($m.zone)", "--project=$($m.projectId)")
if (-not (Test-WorkshopOwnedResource -Resource $inst -RunId $m.runId)) { throw "Instanz gehoert nicht zu run-id $($m.runId)" }
if ($inst.selfLink -ne $m.resources.instance.selfLink) { throw 'selfLink weicht vom Manifest ab' }
$already = $inst.metadata.items | Where-Object { $_.key -eq 'disable-account-manager' -and $_.value -eq 'true' }
if ($already) { Write-WorkshopStep 'Gast-Account-Manager ist bereits deaktiviert'; return }
Invoke-GcloudChange -Arguments @('compute', 'instances', 'add-metadata', $m.resources.instance.name, "--zone=$($m.zone)", "--project=$($m.projectId)", '--metadata=disable-account-manager=true') -Description 'Gast-Account-Manager per Metadaten deaktivieren' | Out-Null
if (Test-WorkshopPlanOnly) { return }
$m.domain.accountManagerDisabledAt = (Get-Date).ToUniversalTime().ToString('o')
Save-WorkshopManifest -Manifest $m -Path $ManifestPath
```

- [ ] **Step 1: Test** (Manifest im `$TestDrive`, Mock von `Invoke-GcloudRaw`: describe liefert Instanz mit
  passenden Labels und selfLink; Erwartung: `add-metadata` genau einmal ohne PlanOnly, null mal mit PlanOnly,
  Abbruch bei fremdem Label).
- [ ] **Step 2: Skript, Tests grün, Analyzer, Commit** `feat(workshops): disable the guest account manager after promotion`

---

### Task 8: `Remove-Workshop.ps1`

**Files:**

- Create: `workshops/active-directory/scripts/Remove-Workshop.ps1`
- Test: `workshops/active-directory/scripts/tests/Remove-Workshop.Tests.ps1`

**Interfaces:**

- Consumes: Manifest; `Get-IapTunnelPolicy`/`Set-IapTunnelPolicy`.
- Produces: Manifest `status = removed`, `removed.<key> = <Zeitpunkt>`; mit `-Local` zusätzlich
  `docker compose -f lab/docker-compose.yml down -v --remove-orphans`.

Reihenfolge und Regeln:

1. `projects describe` muss `projectNumber` des Manifests liefern, sonst Abbruch.
2. IAM: `Get-IapTunnelPolicy`; nur Bindings entfernen, deren `role`, `members` und `condition.title`
   einem Eintrag in `iamBindings` entsprechen; andere Bindings bleiben. Ohne Instanz-ID (Instanz weg):
   überspringen und melden.
3. Instanz: describe; fehlt → `removed.instance`; vorhanden → selfLink gleich und Eigentum → `instances
   delete --zone`; sonst Abbruch dieser Löschung, weiter mit dem Rest wird nicht versucht (Disks hängen).
4. Datendisk, dann Bootdisk (Name = Instanzname): describe; fehlt → als erledigt markieren; vorhanden →
   Eigentum prüfen (Bootdisk trägt die Instanz-Labels) → `disks delete --zone`. Disk mit `users` (noch
   angehängt) → Abbruch.
5. Adressen extern und intern: `addresses delete --region`.
6. Firewallregeln, Subnetz, VPC: `delete`. Subnetz mit fremden Nutzern liefert gcloud-Fehler → Abbruch.
7. `-PlanOnly` listet alle Schritte, ohne zu löschen. `-Local` räumt den Compose-Stack, nur über den
   Projektnamen `keycloak-ad-workshop`.

- [ ] **Step 1: Tests schreiben**

```powershell
Describe 'Remove-Workshop' {
    BeforeEach {
        $script:Manifest = Join-Path $TestDrive 'manifest.json'
        $m = New-WorkshopManifest -ProjectId 'demo-project' -ProjectNumber '123' -Region 'europe-west3' -Zone 'europe-west3-a' -Prefix 'kcad' -RunId '20260915-1200' -ExpiresAt (Get-Date).AddDays(1)
        foreach ($k in 'network','subnet','firewallLdaps','firewallIapRdp','internalAddress','externalAddress','dataDisk','instance') {
            $m.resources[$k] = @{ name = "kcad-$k"; selfLink = "https://x/$k"; scope = 'zone' }
        }
        $m.iamBindings = @(@{ principal = 'user:t@example.org'; role = 'roles/iap.tunnelResourceAccessor'; conditionTitle = 'keycloak-ad-workshop rdp'; instanceId = '42' })
        Save-WorkshopManifest -Manifest $m -Path $script:Manifest
    }
    It 'deletes owned resources in order and marks missing ones as removed' {
        $script:calls = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '; $script:calls.Add($a)
            if ($a -match '^projects describe') { return '{"projectNumber":"123"}' }
            if ($a -match 'disks describe kcad-instance') { throw 'ERROR: was not found' }
            if ($a -match 'describe') { $n = ($Arguments[3]); return "{""name"":""$n"",""selfLink"":""https://x/$($n -replace 'kcad-','')"",""labels"":{""workshop"":""keycloak-ad"",""run-id"":""20260915-1200""},""description"":""keycloak-ad-workshop run-id=20260915-1200""}" }
            return '{}'
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common { @{ etag = 'e'; version = 3; bindings = @(@{ role = 'roles/iap.tunnelResourceAccessor'; members = @('user:t@example.org'); condition = @{ title = 'keycloak-ad-workshop rdp'; expression = 'destination.port == 3389' } }, @{ role = 'roles/viewer'; members = @('user:other@example.org') }) } }
        & "$PSScriptRoot/../Remove-Workshop.ps1" -ManifestPath $script:Manifest -Confirm:$false
        $deletes = $script:calls | Where-Object { $_ -match ' delete ' }
        $deletes[0] | Should -Match 'instances delete kcad-instance'
        $deletes[-1] | Should -Match 'networks delete kcad-network'
        (Read-WorkshopManifest -Path $script:Manifest).status | Should -Be 'removed'
        (Read-WorkshopManifest -Path $script:Manifest).removed.bootDisk | Should -Match 'already'
        Should -Invoke Invoke-IapApi -ModuleName Workshop.Common -Times 1 -ParameterFilter { $Method -eq 'Post' -and $Url -match 'setIamPolicy' -and ($Body.policy.bindings | Measure-Object).Count -eq 1 }
    }
    It 'aborts on a foreign resource with the same name' {
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            if ($a -match '^projects describe') { return '{"projectNumber":"123"}' }
            if ($a -match 'instances describe') { return '{"name":"kcad-instance","selfLink":"https://x/instance","labels":{"workshop":"other"}}' }
            throw 'ERROR: was not found'
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common { @{ bindings = @() } }
        { & "$PSScriptRoot/../Remove-Workshop.ps1" -ManifestPath $script:Manifest -Confirm:$false } | Should -Throw '*Eigentum*'
    }
    It 'does nothing in plan mode' {
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            if ($a -match '^projects describe') { return '{"projectNumber":"123"}' }
            if ($a -match 'describe') { return '{"name":"n","selfLink":"https://x/n","description":"keycloak-ad-workshop run-id=20260915-1200"}' }
            throw "unexpected $a"
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common { @{ bindings = @() } }
        & "$PSScriptRoot/../Remove-Workshop.ps1" -ManifestPath $script:Manifest -PlanOnly
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter { ($Arguments -join ' ') -match ' delete ' }
    }
}
```

- [ ] **Step 2: Skript schreiben** mit `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`,
  `$PSCmdlet.ShouldProcess($m.projectId, "Workshop-Ressourcen run-id $($m.runId) loeschen")` vor der ersten
  Löschung; Reihenfolge und Prüfungen wie oben; Bootdisk-Sonderfall `removed.bootDisk = 'already deleted with instance'`.
- [ ] **Step 3: Tests grün, Analyzer, Commit** `feat(workshops): tear down the AD workshop by manifest`

---

### Task 9: `Initialize-Domain.ps1` (Gast)

**Files:**

- Create: `workshops/active-directory/scripts/Initialize-Domain.ps1`

**Interfaces:**

- Produces: Domäne `ad.mustertech.test`, DC `dc01`, NTDS und SYSVOL auf `D:`, DNS-Forwarder
  `169.254.169.254`, Zeitquelle `metadata.google.internal`, Zustandsdatei `C:\Workshop\state\domain.json`.

Phasenlogik (jeder Aufruf erkennt seine Phase selbst):

```powershell
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$DomainName = 'ad.mustertech.test',
    [string]$NetbiosName = 'MUSTERTECH',
    [string]$ComputerName = 'dc01',
    [char]$DataDriveLetter = 'D',
    [string]$StatePath = 'C:\Workshop\state'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $StatePath -Force | Out-Null

function Write-State { param([string]$Phase, [hashtable]$Data)
    ([ordered]@{ phase = $Phase; at = (Get-Date).ToUniversalTime().ToString('o') } + $Data) |
        ConvertTo-Json | Set-Content (Join-Path $StatePath 'domain.json') }

function Initialize-DataDisk {
    $vol = Get-Volume -ErrorAction SilentlyContinue | Where-Object FileSystemLabel -eq 'ADDS'
    if ($vol) { Write-Host "Datendisk vorhanden: $($vol.DriveLetter):"; return }
    $raw = @(Get-Disk | Where-Object PartitionStyle -eq 'RAW')
    if ($raw.Count -ne 1) { throw "Erwartet genau eine RAW-Disk, gefunden: $($raw.Count)" }
    Initialize-Disk -Number $raw[0].Number -PartitionStyle GPT
    New-Partition -DiskNumber $raw[0].Number -UseMaximumSize -DriveLetter $DataDriveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel 'ADDS' -Confirm:$false | Out-Null
}

$role = (Get-CimInstance Win32_ComputerSystem).DomainRole   # 4/5 = Domain Controller
if ($role -ge 4) {
    Import-Module ActiveDirectory
    $d = Get-ADDomain
    if ($d.DNSRoot -ne $DomainName) { throw "Dieser Server ist DC der fremden Domaene $($d.DNSRoot). Abbruch." }
    # Phase 3: Nacharbeiten nach der Promotion
    Set-DnsServerForwarder -IPAddress 169.254.169.254 -UseRootHint $false
    & w32tm /config /manualpeerlist:"metadata.google.internal" /syncfromflags:manual /reliable:yes /update | Out-Null
    Restart-Service w32time
    $ldaps = Get-NetFirewallRule -DisplayName 'Active Directory Domain Controller - Secure LDAP (TCP-In)' -ErrorAction SilentlyContinue
    if (-not $ldaps) { New-NetFirewallRule -DisplayName 'Workshop LDAPS 636' -Direction Inbound -Protocol TCP -LocalPort 636 -Action Allow | Out-Null }
    New-Item -ItemType Directory -Path 'C:\Workshop\out', 'C:\Workshop\secrets' -Force | Out-Null
    $kms = Test-NetConnection kms.windows.googlecloud.com -Port 1688 -WarningAction SilentlyContinue
    Write-State -Phase 'ready' -Data @{ domain = $d.DNSRoot; dc = "$env:COMPUTERNAME.$($d.DNSRoot)"; kmsReachable = $kms.TcpTestSucceeded }
    Write-Host "Domaene $($d.DNSRoot) bereit. Naechster Schritt: Initialize-Workshop.ps1"
    return
}

if ($env:COMPUTERNAME -ne $ComputerName.ToUpper()) {
    # Phase 1: Datendisk und Umbenennung, danach Neustart
    Initialize-DataDisk
    Write-State -Phase 'renamed' -Data @{ from = $env:COMPUTERNAME; to = $ComputerName }
    Rename-Computer -NewName $ComputerName -Force -Restart
    return
}

# Phase 2: Rolle, lokales Administratorkonto und Promotion, danach Neustart
Initialize-DataDisk
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools | Out-Null
$adminPw = Read-Host -AsSecureString 'Passwort fuer MUSTERTECH\Administrator (wird Domaenen-Admin)'
$adminPw2 = Read-Host -AsSecureString 'Passwort wiederholen'
if ([System.Net.NetworkCredential]::new('', $adminPw).Password -ne [System.Net.NetworkCredential]::new('', $adminPw2).Password) { throw 'Passwoerter stimmen nicht ueberein' }
Enable-LocalUser -Name Administrator
Set-LocalUser -Name Administrator -Password $adminPw -PasswordNeverExpires $true
$dsrm = Read-Host -AsSecureString 'DSRM-Passwort (Directory Services Restore Mode)'
Write-State -Phase 'promoting' -Data @{ domain = $DomainName }
Import-Module ADDSDeployment
Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $NetbiosName `
    -DatabasePath "${DataDriveLetter}:\NTDS" -LogPath "${DataDriveLetter}:\NTDS" -SysvolPath "${DataDriveLetter}:\SYSVOL" `
    -InstallDns -SafeModeAdministratorPassword $dsrm -Force -NoRebootOnCompletion:$false
```

Das Konto `wsadmin` aus `reset-windows-password` verschwindet mit der Promotion; die Anmeldung danach
erfolgt als `MUSTERTECH\Administrator` mit dem in Phase 2 gesetzten Passwort. Der Trainer prüft diese
Anmeldung, bevor `Protect-Workshop.ps1` läuft.

- [ ] **Step 1: Skript schreiben** (Code oben vollständig übernehmen).
- [ ] **Step 2: Analyzer** `Invoke-ScriptAnalyzer -Path workshops/active-directory/scripts/Initialize-Domain.ps1 -Severity Warning,Error`
  und Parse-Test `[System.Management.Automation.Language.Parser]::ParseFile(...)` ohne Fehler.
- [ ] **Step 3: Commit** `feat(workshops): promote the AD workshop DC in guest`

---

### Task 10: `Initialize-Workshop.ps1` (Gast)

**Files:**

- Create: `workshops/active-directory/scripts/Initialize-Workshop.ps1`

**Interfaces:**

- Produces: Workshop-CA `CN=Keycloak Workshop CA` (Root-Store), LDAPS-Serverzertifikat für
  `dc01.ad.mustertech.test`, OUs, Gruppen, Benutzer, Delegation, `C:\Workshop\out\workshop-ca.crt`,
  `C:\Workshop\out\workshop-ad.json`, `C:\Workshop\secrets\team<NN>.json`.

```powershell
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidatePattern('^\d{2}$')][string[]]$Teams = @('01', '02', '03'),
    [Parameter(Mandatory)][datetime]$CertificateValidUntil,
    [string]$DcFqdn = 'dc01.ad.mustertech.test',
    [string]$OutputPath = 'C:\Workshop\out',
    [string]$SecretsPath = 'C:\Workshop\secrets',
    [int]$PasswordLength = 20,
    [switch]$ResetPasswords
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domain = Get-ADDomain
if ("$env:COMPUTERNAME.$($domain.DNSRoot)".ToLower() -ne $DcFqdn.ToLower()) { throw "Dieser Host ist nicht $DcFqdn" }
$baseDn = "OU=Workshop,$($domain.DistinguishedName)"
$netbios = $domain.NetBIOSName
New-Item -ItemType Directory -Path $OutputPath, $SecretsPath -Force | Out-Null

function New-WorkshopPassword {
    param([int]$Length)
    $alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'.ToCharArray()
    $symbols = '!$%&*+-=?@'.ToCharArray()
    $bytes = [byte[]]::new($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $chars = for ($i = 0; $i -lt $Length; $i++) { $alphabet[$bytes[$i] % $alphabet.Length] }
    $chars[3] = $symbols[$bytes[0] % $symbols.Length]
    $chars[7] = 'Q'; $chars[11] = '7'; $chars[15] = 'x'
    return -join $chars
}

function Get-OrCreateCa {
    $ca = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=Keycloak Workshop CA' -and $_.HasPrivateKey }
    if (-not $ca) {
        $ca = New-SelfSignedCertificate -Subject 'CN=Keycloak Workshop CA' -KeyAlgorithm RSA -KeyLength 4096 -HashAlgorithm SHA256 `
            -KeyUsage CertSign, CRLSign, DigitalSignature -KeyExportPolicy NonExportable -NotAfter $CertificateValidUntil `
            -CertStoreLocation Cert:\LocalMachine\My -TextExtension @('2.5.29.19={critical}{text}ca=true&pathlength=0')
    }
    $root = [System.Security.Cryptography.X509Certificates.X509Store]::new('Root', 'LocalMachine')
    $root.Open('ReadWrite')
    if (-not ($root.Certificates | Where-Object Thumbprint -eq $ca.Thumbprint)) { $root.Add([System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ca.RawData)) }
    $root.Close()
    return $ca
}

function Get-OrCreateServerCertificate {
    param($Ca)
    $existing = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Issuer -eq $Ca.Subject -and $_.DnsNameList.Unicode -contains $DcFqdn -and $_.NotAfter -ge $CertificateValidUntil.AddMinutes(-5) }
    if ($existing) { return $existing | Select-Object -First 1 }
    $cert = New-SelfSignedCertificate -DnsName $DcFqdn, ($DcFqdn.Split('.')[0]) -Signer $Ca -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
        -KeyExportPolicy NonExportable -KeySpec KeyExchange -NotAfter $CertificateValidUntil -CertStoreLocation Cert:\LocalMachine\My `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.1')
    $rootDse = [ADSI]'LDAP://localhost/RootDSE'
    $rootDse.Put('renewServerCertificate', 1)
    $rootDse.SetInfo()
    return $cert
}

function Export-CaPem {
    param($Ca)
    $b64 = [Convert]::ToBase64String($Ca.RawData, 'InsertLineBreaks')
    "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----`n" | Set-Content -Path (Join-Path $OutputPath 'workshop-ca.crt') -Encoding ascii -NoNewline
    return (($Ca.GetCertHash('SHA256') | ForEach-Object { $_.ToString('X2') }) -join ':')
}

function Ensure-Ou {
    param([string]$Name, [string]$Parent)
    $dn = "OU=$Name,$Parent"
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$Name)" -SearchBase $Parent -SearchScope OneLevel -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Name -Path $Parent -ProtectedFromAccidentalDeletion $false | Out-Null
    }
    return $dn
}

function Ensure-Group {
    param([string]$Name, [string]$Sam, [string]$Path)
    $g = Get-ADGroup -LDAPFilter "(sAMAccountName=$Sam)" -ErrorAction SilentlyContinue
    if (-not $g) { $g = New-ADGroup -Name $Name -SamAccountName $Sam -GroupScope Global -GroupCategory Security -Path $Path -PassThru }
    return $g
}

function Ensure-User {
    param([string]$Sam, [string]$Given, [string]$Surname, [string]$Path, [string]$Password, [switch]$Service)
    $upn = "$Sam@$($domain.DNSRoot)"
    $u = Get-ADUser -LDAPFilter "(sAMAccountName=$Sam)" -ErrorAction SilentlyContinue
    if (-not $u) {
        $u = New-ADUser -Name "$Given $Surname" -GivenName $Given -Surname $Surname -SamAccountName $Sam -UserPrincipalName $upn `
            -EmailAddress $upn -Path $Path -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -Enabled $true `
            -PasswordNeverExpires $true -CannotChangePassword:$Service -ChangePasswordAtLogon $false -PassThru
    } elseif ($ResetPasswords) {
        Set-ADAccountPassword -Identity $u -Reset -NewPassword (ConvertTo-SecureString $Password -AsPlainText -Force)
    }
    return $u
}

function Grant-Delegation {
    param([string]$Operator, [string]$UsersDn, [string]$MovedDn, [string]$GroupsDn)
    foreach ($ou in $UsersDn, $MovedDn) {
        & dsacls $ou /G "${netbios}\${Operator}:CCDC;user" | Out-Null
        & dsacls $ou /I:S /G "${netbios}\${Operator}:WP;userAccountControl;user" "${netbios}\${Operator}:WP;cn;user" "${netbios}\${Operator}:WP;name;user" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "dsacls auf $ou fehlgeschlagen" }
    }
    & dsacls $GroupsDn /I:S /G "${netbios}\${Operator}:WP;member;group" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "dsacls auf $GroupsDn fehlgeschlagen" }
}

$ca = Get-OrCreateCa
$server = Get-OrCreateServerCertificate -Ca $ca
$fingerprint = Export-CaPem -Ca $ca
Ensure-Ou -Name 'Workshop' -Parent $domain.DistinguishedName | Out-Null

$summary = [ordered]@{ dcFqdn = $DcFqdn; domain = $domain.DNSRoot; baseDn = $baseDn; caSubject = $ca.Subject; caFingerprintSha256 = $fingerprint; caNotAfter = $ca.NotAfter.ToString('o'); serverCertNotAfter = $server.NotAfter.ToString('o'); teams = [ordered]@{} }

foreach ($t in $Teams) {
    $teamDn = Ensure-Ou -Name "Team$t" -Parent $baseDn
    $usersDn = Ensure-Ou -Name 'Users' -Parent $teamDn
    $movedDn = Ensure-Ou -Name 'Moved' -Parent $teamDn
    $groupsDn = Ensure-Ou -Name 'Groups' -Parent $teamDn
    $svcDn = Ensure-Ou -Name 'ServiceAccounts' -Parent $teamDn

    $secretFile = Join-Path $SecretsPath "team$t.json"
    $secrets = if ((Test-Path $secretFile) -and -not $ResetPasswords) { Get-Content $secretFile -Raw | ConvertFrom-Json -AsHashtable } else {
        @{ hans = New-WorkshopPassword $PasswordLength; anna = New-WorkshopPassword $PasswordLength; bind = New-WorkshopPassword $PasswordLength; operator = New-WorkshopPassword $PasswordLength } }

    $hans = Ensure-User -Sam "t$t.hans" -Given 'Hans' -Surname 'Mueller' -Path $usersDn -Password $secrets.hans
    $anna = Ensure-User -Sam "t$t.anna" -Given 'Anna' -Surname 'Schmidt' -Path $usersDn -Password $secrets.anna
    $bind = Ensure-User -Sam "t$t.bind" -Given "Bind" -Surname "Team$t" -Path $svcDn -Password $secrets.bind -Service
    $operator = Ensure-User -Sam "t$t.operator" -Given "Operator" -Surname "Team$t" -Path $svcDn -Password $secrets.operator -Service

    $staff = Ensure-Group -Name 'Mitarbeiter' -Sam "t$t.staff" -Path $groupsDn
    $leads = Ensure-Group -Name 'Teamleitung' -Sam "t$t.leads" -Path $groupsDn
    $managers = Ensure-Group -Name 'Manager' -Sam "t$t.managers" -Path $groupsDn
    Add-ADGroupMember -Identity $staff -Members $hans, $anna -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity $leads -Members $anna -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity $managers -Members $leads -ErrorAction SilentlyContinue

    Grant-Delegation -Operator "t$t.operator" -UsersDn $usersDn -MovedDn $movedDn -GroupsDn $groupsDn

    $secrets | ConvertTo-Json | Set-Content $secretFile -Encoding utf8
    $acl = Get-Acl $secretFile
    $acl.SetAccessRuleProtection($true, $false)
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
    foreach ($p in 'BUILTIN\Administrators', 'NT AUTHORITY\SYSTEM') { $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($p, 'FullControl', 'Allow')) }
    Set-Acl $secretFile $acl

    $summary.teams["team$t"] = [ordered]@{
        ou = $teamDn; usersDn = $usersDn; movedDn = $movedDn; groupsDn = $groupsDn; serviceAccountsDn = $svcDn
        bindUpn = $bind.UserPrincipalName; operatorUpn = $operator.UserPrincipalName
        users = @{ hans = $hans.DistinguishedName; anna = $anna.DistinguishedName }
        groups = @{ Mitarbeiter = $staff.DistinguishedName; Teamleitung = $leads.DistinguishedName; Manager = $managers.DistinguishedName }
    }
}

$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $OutputPath 'workshop-ad.json') -Encoding utf8
Write-Host "CA-Fingerprint SHA256: $fingerprint"
Write-Host "Ausgabe: $OutputPath\workshop-ca.crt, $OutputPath\workshop-ad.json; Geheimnisse: $SecretsPath\team<NN>.json"
```

- [ ] **Step 1: Skript schreiben**, Analyzer und Parse-Test wie in Task 9.
- [ ] **Step 2: Commit** `feat(workshops): prepare CA, teams and delegation on the workshop DC`

---

### Task 11: `Reset-Team.ps1` (Gast)

**Files:**

- Create: `workshops/active-directory/scripts/Reset-Team.ps1`

```powershell
#Requires -RunAsAdministrator
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^\d{2}$')][string]$Team)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain
$teamDn = "OU=Team$Team,OU=Workshop,$($domain.DistinguishedName)"
$usersDn = "OU=Users,$teamDn"
function Get-TeamUser { param($Sam) Get-ADUser -LDAPFilter "(sAMAccountName=$Sam)" -SearchBase $teamDn -Properties memberOf, userAccountControl }
function Get-TeamGroup { param($Sam) Get-ADGroup -LDAPFilter "(sAMAccountName=$Sam)" -SearchBase $teamDn }
$hans = Get-TeamUser "t$Team.hans"; $anna = Get-TeamUser "t$Team.anna"
$staff = Get-TeamGroup "t$Team.staff"; $leads = Get-TeamGroup "t$Team.leads"; $managers = Get-TeamGroup "t$Team.managers"
if (-not ($hans -and $anna -and $staff -and $leads -and $managers)) { throw "Team $Team ist unvollstaendig" }

foreach ($u in $hans, $anna) {
    if ($u.DistinguishedName -notlike "*,$usersDn") { Write-Host "verschiebe $($u.Name) nach Users"; Move-ADObject -Identity $u -TargetPath $usersDn }
    if (-not $u.Enabled) { Write-Host "aktiviere $($u.Name)"; Enable-ADAccount -Identity $u }
}
$baseline = @{ $staff.DistinguishedName = @($hans.SID.Value, $anna.SID.Value); $leads.DistinguishedName = @($anna.SID.Value); $managers.DistinguishedName = @($leads.SID.Value) }
foreach ($g in $staff, $leads, $managers) {
    $current = @(Get-ADGroupMember -Identity $g | ForEach-Object { $_.SID.Value })
    $wanted = $baseline[$g.DistinguishedName]
    foreach ($sid in ($current | Where-Object { $_ -notin $wanted })) { Write-Host "entferne $sid aus $($g.Name)"; Remove-ADGroupMember -Identity $g -Members $sid -Confirm:$false }
    foreach ($sid in ($wanted | Where-Object { $_ -notin $current })) { Write-Host "fuege $sid zu $($g.Name) hinzu"; Add-ADGroupMember -Identity $g -Members $sid }
}
Get-TeamUser "t$Team.hans", "t$Team.anna" | Out-Null
'hans', 'anna' | ForEach-Object { $u = Get-TeamUser "t$Team.$_"; [pscustomobject]@{ User = $u.SamAccountName; DN = $u.DistinguishedName; Enabled = $u.Enabled; UAC = $u.userAccountControl; Groups = ($u.memberOf | ForEach-Object { ($_ -split ',')[0] }) -join ', ' } } | Format-Table -AutoSize
```

- [ ] **Step 1: Skript, Analyzer, Parse-Test.**
- [ ] **Step 2: Commit** `feat(workshops): reset a team to the AD baseline`

---

### Task 12: `Test-Workshop.ps1`

**Files:**

- Create: `workshops/active-directory/scripts/Test-Workshop.ps1`
- Test: `workshops/active-directory/scripts/tests/Test-Workshop.Tests.ps1` (nur die Berichtsfunktion
  und die Firewall-Auswertung, beide ohne gcloud)

**Interfaces:**

- Consumes: Manifest, `.run/secrets/team<NN>.json` (vom DC kopiert), `lab/certs/workshop-ca.crt`,
  laufender Werkzeugcontainer.
- Produces: Bericht `.run/report-<mode>-<yyyyMMdd-HHmm>.json` mit `[{id, name, result, detail}]`,
  Exit-Code 1 bei einem Fehlschlag.

Parameter: `-Mode Trainer|Guest` (Mandatory), `-ManifestPath`, `-Teams`, `-IncludeIap`, `-SecretsPath`,
`-LabPath` (Standard `..\lab`).

Prüfungen im Modus `Trainer`:

| Id  | Prüfung                                                                 | Erwartung                                |
| --- | ----------------------------------------------------------------------- | ---------------------------------------- |
| T01 | `projects describe` Nummer = Manifest                                   | gleich                                   |
| T02 | Instanz RUNNING, Labels, selfLink                                       | Eigentum nachgewiesen                    |
| T03 | Metadaten `disable-account-manager=true`                                | gesetzt                                  |
| T04 | Effektive Firewalls der Instanz (`network-interfaces get-effective-firewalls`) | keine ALLOW-Regel mit `0.0.0.0/0` auf 636 oder 3389; 636 nur aus Manifest-Quellen |
| T05 | TCP 636 zur externen IP                                                 | offen                                    |
| T06 | `openssl s_client -CAfile ca -verify_hostname <fqdn> -verify_return_error` | `Verify return code: 0 (ok)`          |
| T07 | wie T06 mit `-verify_hostname wrong.example`                            | Fehler                                   |
| T08 | wie T06 ohne `-CAfile`                                                  | Fehler                                   |
| T09 | TCP 3389 direkt zur externen IP                                         | geschlossen                              |
| T10 | je Team: Bind + Suche als `t<NN>.bind` unter Team-OU mit Filter          | genau 2 Einträge (`t<NN>.hans`, `t<NN>.anna`) |
| T11 | je Team: Suche unter `OU=Users` findet Bind- und Übungskonto nicht      | 0 Einträge                               |
| T12 | je Team: `ldapmodify` als Bind-Konto (description an Hans)              | Fehler 50 (insufficientAccessRights)     |
| T13 | je Team: `ldapmodify` als Übungskonto auf Hans des Nachbarteams          | Fehler 50                                |
| T14 | je Team: `ldapmodify` als Übungskonto auf eigenen Hans (description setzen und löschen) | Erfolg                     |
| T15 | mit `-IncludeIap`: Tunnel starten, lokalen Port verbinden, beenden       | offen                                    |

LDAP-Aufrufe laufen über `docker compose -f <LabPath>/docker-compose.yml exec -T ldap-tools ...` mit
`-y`-Dateien, die das Skript aus `team<NN>.json` temporär unter `lab/secrets/` anlegt und danach löscht.

Prüfungen im Modus `Guest` (auf dem DC, als Domänen-Admin):

| Id  | Prüfung                                                                | Erwartung                  |
| --- | ---------------------------------------------------------------------- | -------------------------- |
| G01 | `Get-ADDomain` DNSRoot, Hostname                                       | `ad.mustertech.test`, dc01 |
| G02 | NTDS und SYSVOL auf `D:`                                               | Pfade vorhanden            |
| G03 | DNS-Forwarder `169.254.169.254`, `Resolve-DnsName kms.windows.googlecloud.com` | auflösbar          |
| G04 | KMS TCP 1688 und Lizenzstatus (`SoftwareLicensingProduct.LicenseStatus`) | erreichbar, 1 = licensed |
| G05 | `w32tm /query /status` Quelle                                          | `metadata.google.internal` |
| G06 | LDAPS-Zertifikat: `SslStream` auf 636 mit Kettenprüfung, SAN, EKU, NotAfter | gültig                |
| G07 | je Team: OUs, 3 Gruppen, 4 Konten, Mitgliedschaften                    | Baseline                   |
| G08 | je Team: Übungskonto darf eigenes `member` ändern (`-Credential`)      | Erfolg und Rücknahme       |
| G09 | je Team: Übungskonto gegen Nachbarteam und gegen eigenes Bind-Konto    | AccessDenied               |
| G10 | Firewallregel LDAPS aktiviert                                          | Enabled                    |

- [ ] **Step 1: Test für Berichts- und Firewall-Auswertung**

```powershell
Describe 'Test-Workshop helpers' {
    BeforeAll { . "$PSScriptRoot/../Test-Workshop.ps1" -Mode Trainer -HelpersOnly }
    It 'flags an allow rule from anywhere on 636' {
        $fw = @([pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('0.0.0.0/0')
                allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('636') }) })
        (Test-EffectiveFirewall -Rules $fw -AllowedLdapsRanges @('203.0.113.0/24')).Result | Should -Be 'FAIL'
    }
    It 'accepts the two workshop rules' {
        $fw = @(
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('203.0.113.0/24')
                allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('636') }) },
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('35.235.240.0/20')
                allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('3389') }) }
        )
        (Test-EffectiveFirewall -Rules $fw -AllowedLdapsRanges @('203.0.113.0/24')).Result | Should -Be 'PASS'
    }
    It 'sets exit code 1 when a check fails' {
        $r = @([pscustomobject]@{ id = 'X'; name = 'x'; result = 'FAIL'; detail = '' })
        Get-ReportExitCode -Report $r | Should -Be 1
    }
}
```

Das Skript unterstützt dafür `-HelpersOnly`: Es definiert nur die Funktionen und kehrt zurück.

- [ ] **Step 2: Skript schreiben** mit `Add-Check -Id -Name -Test { ... }` (fängt Ausnahmen, `PASS`/`FAIL`/
  `SKIP`), Ausgabe als Tabelle, JSON-Bericht, `exit (Get-ReportExitCode -Report $report)`.
- [ ] **Step 3: Pester, Analyzer, Commit** `feat(workshops): verify the AD workshop from trainer and guest`

---

### Task 13: Trainerlösung `solution/`

**Files:**

- Create: `workshops/active-directory/solution/apply-solution.sh`
- Create: `workshops/active-directory/solution/README.md`

**Interfaces:**

- Consumes: Keycloak-Container mit `/workshop/solution` und `/workshop/secrets/bind.pw`.
- Produces: LDAP-Provider `ad-team<NN>` und Group-Mapper `ad-groups` im Realm `mustertech`.

Aufruf aus `lab/`: `docker compose exec -e TEAM=01 keycloak bash /workshop/solution/apply-solution.sh <befehl>`

Befehle: `create` (Provider + Group-Mapper, direkte Strategie, Users DN `OU=Users`), `strategy direct|recursive`,
`users-dn users|team`, `sync` (Full-Sync Benutzer und Gruppen), `logout-sessions` (alle Sessions im Realm),
`status` (Providerkonfiguration und Gruppen der beiden Benutzer), `delete`.

```bash
#!/usr/bin/env bash
# Trainerloesung: LDAP-Provider fuer ein Team per kcadm anlegen und umstellen.
# Aufruf im Keycloak-Container:
#   TEAM=01 bash /workshop/solution/apply-solution.sh <befehl> [arg]
#   Befehle: create | strategy direct|recursive | users-dn users|team | sync | logout-sessions | status | delete
set -euo pipefail

TEAM="${TEAM:?TEAM=01|02|03 setzen}"
REALM=mustertech
KCADM=/opt/keycloak/bin/kcadm.sh
BASE="DC=ad,DC=mustertech,DC=test"
TEAM_DN="OU=Team${TEAM},OU=Workshop,${BASE}"
USERS_DN="OU=Users,${TEAM_DN}"
GROUPS_DN="OU=Groups,${TEAM_DN}"
BIND_DN="t${TEAM}.bind@ad.mustertech.test"
BIND_PW_FILE="${BIND_PW_FILE:-/workshop/secrets/bind.pw}"
PROVIDER_NAME="ad-team${TEAM}"

login() {
  "$KCADM" config credentials --server http://localhost:8080 --realm master --user admin --password admin >/dev/null
}

realm_id() { "$KCADM" get "realms/${REALM}" --fields id --format csv --noquotes; }

provider_id() {
  "$KCADM" get components -r "$REALM" -q name="$PROVIDER_NAME" -q type=org.keycloak.storage.UserStorageProvider \
    --fields id --format csv --noquotes | head -n1
}

mapper_id() {
  "$KCADM" get components -r "$REALM" -q parent="$1" -q name=ad-groups --fields id --format csv --noquotes | head -n1
}

require_provider() {
  PID="$(provider_id)"
  if [ -z "$PID" ]; then
    echo "Provider $PROVIDER_NAME existiert nicht. Zuerst: create" >&2
    exit 1
  fi
  MID="$(mapper_id "$PID")"
}

create() {
  if [ ! -r "$BIND_PW_FILE" ]; then
    echo "Bind-Passwort fehlt: $BIND_PW_FILE (im Werkzeugcontainer: save-secret bind)" >&2
    exit 1
  fi
  if [ -n "$(provider_id)" ]; then
    echo "Provider $PROVIDER_NAME existiert bereits" >&2
    exit 1
  fi
  local rid
  rid="$(realm_id)"
  "$KCADM" create components -r "$REALM" \
    -s name="$PROVIDER_NAME" -s providerId=ldap -s parentId="$rid" \
    -s providerType=org.keycloak.storage.UserStorageProvider \
    -s 'config.enabled=["true"]' -s 'config.priority=["0"]' -s 'config.vendor=["ad"]' \
    -s 'config.editMode=["READ_ONLY"]' -s 'config.importEnabled=["true"]' -s 'config.syncRegistrations=["false"]' \
    -s 'config.connectionUrl=["ldaps://dc01.ad.mustertech.test:636"]' -s 'config.useTruststoreSpi=["always"]' \
    -s 'config.startTls=["false"]' -s 'config.connectionPooling=["false"]' \
    -s "config.usersDn=[\"${USERS_DN}\"]" -s 'config.searchScope=["2"]' \
    -s 'config.authType=["simple"]' -s "config.bindDn=[\"${BIND_DN}\"]" \
    -s "config.bindCredential=[\"$(cat "$BIND_PW_FILE")\"]" \
    -s 'config.usernameLDAPAttribute=["userPrincipalName"]' -s 'config.rdnLDAPAttribute=["cn"]' \
    -s 'config.uuidLDAPAttribute=["objectGUID"]' \
    -s 'config.userObjectClasses=["person, organizationalPerson, user"]' \
    -s "config.customUserSearchFilter=[\"(|(sAMAccountName=t${TEAM}.hans)(sAMAccountName=t${TEAM}.anna))\"]" \
    -s 'config.pagination=["true"]' -s 'config.batchSizeForSync=["1000"]' -s 'config.trustEmail=["false"]' \
    -s 'config.cachePolicy=["DEFAULT"]' -s 'config.fullSyncPeriod=["-1"]' -s 'config.changedSyncPeriod=["-1"]' \
    -s 'config.allowKerberosAuthentication=["false"]' -s 'config.useKerberosForPasswordAuthentication=["false"]' \
    -s 'config.validatePasswordPolicy=["false"]' -s 'config.usePasswordModifyExtendedOp=["false"]'
  local pid
  pid="$(provider_id)"
  "$KCADM" create components -r "$REALM" \
    -s name=ad-groups -s providerId=group-ldap-mapper \
    -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper -s parentId="$pid" \
    -s "config.\"groups.dn\"=[\"${GROUPS_DN}\"]" -s 'config."group.name.ldap.attribute"=["cn"]' \
    -s 'config."group.object.classes"=["group"]' -s 'config."preserve.group.inheritance"=["false"]' \
    -s 'config."ignore.missing.groups"=["false"]' -s 'config."membership.ldap.attribute"=["member"]' \
    -s 'config."membership.attribute.type"=["DN"]' -s 'config."membership.user.ldap.attribute"=["cn"]' \
    -s 'config."groups.ldap.filter"=[""]' -s 'config.mode=["READ_ONLY"]' \
    -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"]' \
    -s 'config."memberof.ldap.attribute"=["memberOf"]' -s 'config."mapped.group.attributes"=[""]' \
    -s 'config."drop.non.existing.groups.during.sync"=["false"]' -s 'config."groups.path"=["/"]'
  echo "Provider $PROVIDER_NAME und Mapper ad-groups angelegt"
}

strategy() {
  require_provider
  case "${1:-}" in
    direct)
      "$KCADM" update "components/${MID}" -r "$REALM" \
        -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"]' ;;
    recursive)
      "$KCADM" update "components/${MID}" -r "$REALM" \
        -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY"]' ;;
    *) echo "strategy direct|recursive" >&2; exit 2 ;;
  esac
  echo "Strategie: $1"
}

users_dn() {
  require_provider
  case "${1:-}" in
    users) "$KCADM" update "components/${PID}" -r "$REALM" -s "config.usersDn=[\"${USERS_DN}\"]" ;;
    team) "$KCADM" update "components/${PID}" -r "$REALM" -s "config.usersDn=[\"${TEAM_DN}\"]" ;;
    *) echo "users-dn users|team" >&2; exit 2 ;;
  esac
  echo "Users DN: $1"
}

sync() {
  require_provider
  "$KCADM" create "user-storage/${PID}/sync?action=triggerFullSync" -r "$REALM"
  "$KCADM" create "user-storage/${PID}/mappers/${MID}/sync?direction=fedToKeycloak" -r "$REALM"
}

logout_sessions() {
  "$KCADM" create logout-all -r "$REALM"
  echo "alle Sitzungen im Realm $REALM beendet"
}

status() {
  require_provider
  "$KCADM" get "components/${PID}" -r "$REALM" --fields 'config(usersDn,customUserSearchFilter,editMode,vendor)'
  "$KCADM" get "components/${MID}" -r "$REALM" \
    --fields 'config(user.roles.retrieve.strategy,groups.dn,preserve.group.inheritance)'
  for u in hans anna; do
    echo "--- t${TEAM}.${u}@ad.mustertech.test"
    uid="$("$KCADM" get users -r "$REALM" -q "username=t${TEAM}.${u}@ad.mustertech.test" -q exact=true \
      --fields id --format csv --noquotes | head -n1)"
    if [ -n "$uid" ]; then
      "$KCADM" get "users/${uid}/groups" -r "$REALM" --fields name --format csv --noquotes
    else
      echo "(nicht importiert)"
    fi
  done
}

delete_provider() {
  require_provider
  "$KCADM" delete "components/${PID}" -r "$REALM"
  echo "Provider $PROVIDER_NAME geloescht"
}

login
case "${1:-}" in
  create) create ;;
  strategy) strategy "${2:-}" ;;
  users-dn) users_dn "${2:-}" ;;
  sync) sync ;;
  logout-sessions) logout_sessions ;;
  status) status ;;
  delete) delete_provider ;;
  *)
    echo "Befehle: create | strategy direct|recursive | users-dn users|team | sync |" >&2
    echo "         logout-sessions | status | delete" >&2
    exit 2 ;;
esac
```

Der genaue Endpunkt für "alle Sitzungen beenden" und die Mapper-Schlüssel werden im lokalen Test
gegen 26.5.7 belegt; Abweichungen im Skript korrigieren, nicht in der Doku umschreiben.

- [ ] **Step 1: `bash -n solution/apply-solution.sh`** und `shellcheck`, falls installiert.
- [ ] **Step 2: Lokal gegen den laufenden Stack prüfen**, soweit ohne AD möglich: `status` ohne Provider
  liefert eine klare Meldung; `create` ohne Passwortdatei bricht mit Hinweis ab. Vollständiger Test folgt in Task 15.
- [ ] **Step 3: `solution/README.md`**: Zweck, Aufruf je Befehl, Reihenfolge im Workshop (create → sync →
  strategy recursive → sync → users-dn team → sync → Rücknahme), Hinweis auf Geheimnisdatei.
- [ ] **Step 4: Commit** `feat(workshops): add the trainer solution for the AD LDAP provider`

---

### Task 14: README, Aufgabe und Traineranleitung

**Files:**

- Create: `workshops/active-directory/README.md`
- Create: `workshops/active-directory/aufgabe.md`
- Create: `workshops/active-directory/trainer.md`

**README.md** (beschreibend, ohne Leseransprache):

1. Titel `# Workshop: Keycloak an Active Directory auf GCP`, ein Absatz Zweck, Voraussetzungen
   (Modul 06b, Modul 07 mit Lab 07c, Docker Compose, PowerShell 7 und gcloud beim Trainer).
2. Tabelle "Ablauf" mit den sechs Zeitblöcken aus der Spec.
3. Tabelle "Unterlagen": aufgabe.md, trainer.md, solution/, lab/, scripts/.
4. Abschnitt "Ressourcen und Kosten": Ressourcenliste (VPC, Subnetz, 2 Firewallregeln, 2 Adressen,
   VM e2-standard-2, Bootdisk 64 GiB, Datendisk 20 GiB, IAP-Bindung), Listenpreise Frankfurt mit
   Datum der Prüfung (Cloud Billing Catalog, 2026-09-15): E2-Core 0,0281 USD/h, E2-RAM 0,0038 USD/GiB-h,
   Windows-Server-Lizenz 0,046 USD/vCPU-h, pd-balanced 0,12 USD/GiB-Monat, externe IP 0,005 USD/h.
   Summe rund 0,20 USD je Stunde, rund 9,50 USD für 48 Stunden. Hinweis: gestoppte VM kostet weiter
   Disks und Adresse.
5. Abschnitt "Betrieb": Reihenfolge der Skripte (New → RDP über IAP → Initialize-Domain dreimal →
   Initialize-Workshop → Protect → Test Guest → Test Trainer → Workshop → Remove) mit je einem Befehl.
6. Abschnitt "Ersatz ohne GCP": OpenLDAP-Lab 07c und `workshops/ldap-ad`; welche Versuche dann nur
   besprochen werden.
7. Abschnitt "Sicherheitsgrenzen": Quell-IP-Beschränkung, IAP-only RDP, CA-Verteilung, keine Geheimnisse
   im Repo, Abbau nur per Manifest.

**aufgabe.md** (Teilnehmer, geduzt in der Ihr-Form wie `workshops/ldap-ad/aufgabe.md`):

1. `# Active Directory: Vom Verzeichnis bis zur API`, `## Übungsziel` mit "Am Ende dieser Übung habt ihr:"
   und sechs Ergebnissen im Perfekt, `**Dauer:** 90 Minuten`.
2. `## Voraussetzungen`: Teamnummer, Zettel vom Trainer (IP, CA-Fingerprint, vier Passwörter), Stack
   starten (`cp .env.example .env`, CA nach `certs/`, `docker compose up -d --build`), Hinweis-Blockzitat
   zum Beenden anderer Labs mit Link auf `../../labs/assignments/TROUBLESHOOTING.md#container-name-konflikt`,
   Passwörter mit `docker compose exec -it ldap-tools save-secret bind` und `... operator` ablegen,
   Fingerprint prüfen (`openssl x509 -in /certs/workshop-ca.crt -noout -fingerprint -sha256` im Container).
3. `## Versuch 1: AD-Einträge lesen (0-15)`: ldapsearch-Befehle für Bash und PowerShell (Basis Team-OU,
   Filter `(sAMAccountName=t01.hans)`, Attribute `dn userPrincipalName objectGUID memberOf`), `decode-guid`,
   Tabelle zum Ausfüllen (DN, UPN, GUID, direkte Gruppen von Hans und Anna), Frage: Warum taucht `Manager`
   bei Anna nicht in `memberOf` auf?
4. `## Versuch 2: Keycloak über LDAPS verbinden (15-35)`: Klickweg in der Admin-Konsole (User federation →
   Add LDAP provider) mit allen Feldwerten aus der Spec, Test connection / Test authentication, Save,
   Sync all users, Mapper prüfen; Login im privaten Fenster als `t01.hans@ad.mustertech.test` am Portal;
   Vorhersage vor jedem Schritt; API-Buttons: `/api/profile` 200, `/api/urlaubsantraege` erwartbar 403,
   Frage: Warum 403 trotz erfolgreicher Anmeldung? (Gruppen fehlen noch.)
5. `## Versuch 3: Gruppen und verschachtelte Gruppen (35-55)`: Group Mapper anlegen (Felder), Sync LDAP
   groups to Keycloak, Sync all users; Anna anmelden: `/api/urlaubsantraege/alle` → Vorhersage, Ergebnis
   403; Strategie auf `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY`, erneut Sync, neu anmelden → 200;
   Hans → 403; ohne Token (`curl` ohne Header) → 401. `iat`/`exp` aus dem Token notieren.
6. `## Versuch 4: Hans in Moved verschieben (55-65)`: DN, GUID, Keycloak-ID notieren;
   `ldapmodify -f /ldif/team01/01-hans-nach-moved.ldif` als Übungskonto; Suche unter `OU=Users` (0 Treffer)
   und unter der Team-OU (1 Treffer); Login-Versuch als Hans → Beobachtung eintragen; Users DN auf die
   Team-OU erweitern, Filter behalten, Sync, Login; Vergleich GUID und Keycloak-ID.
7. `## Versuch 5: Rechte entziehen und Konto sperren (65-80)`: Token von Anna sichern (Portal "Access Token
   anzeigen"), LDIF 02 anwenden, alten Token gegen `/api/urlaubsantraege/alle` bis `exp` testen
   (Bash `curl`, PowerShell `Invoke-WebRequest`), Sync, neuer Login → 403; LDIF 03 (Hans deaktivieren),
   frischer Login im privaten Fenster → Meldung, bestehende Sitzung im anderen Fenster, Refresh, alter Token
   gegen API; alles mit Zeitpunkt notieren.
8. `## Versuch 6: Rücknahme (80-90)`: LDIF 04, 05, 06 in dieser Reihenfolge, Users DN zurück auf
   `OU=Users`, Strategie zurück auf direkt oder rekursiv lassen (Begründung), Sync, Sessions in Keycloak
   beenden, frische Logins beider Benutzer, beide API-Fälle.
9. `## Auswertung`: vier Leitfragen aus der Spec.

Jeder Befehl in Bash und PowerShell, Unterschied nur Zeilenfortsetzung und Anführungszeichen. Basis ist
`workshops/active-directory/lab`. Kein Passwort im Klartext; überall `-y /secrets/bind.pw` oder
`-y /secrets/operator.pw`.

**trainer.md**:

1. `# Traineranleitung: Active Directory auf GCP`, Vorbereitung (Zeitplan: Bereitstellung am Vortag, Probelauf,
   Zettel je Team, Ausgangs-IPs der Gruppen erfragen).
2. `## Bereitstellung`: Befehle in Reihenfolge mit Beispielwerten, RDP über IAP (`start-iap-tunnel` und
   Windows App), Skripttransfer (Zwischenablage oder `Invoke-WebRequest` aus dem öffentlichen Repository),
   Phasen von `Initialize-Domain.ps1`, Anmeldung als `MUSTERTECH\Administrator` prüfen, dann `Protect-Workshop.ps1`.
3. `## Musterlösung je Versuch`: Erwartete Werte und die im Probelauf beobachteten Ergebnisse (werden in
   Task 15 eingetragen): Provider-Konfiguration, Mapper-Felder, Verhalten bei verschobenem Benutzer,
   Refresh und SSO nach Deaktivierung, Token-Zeiten.
4. `## Diagnoseleiter`: DNS → TCP → TLS → Bind → Suche; fehlender Benutzer: Basis, Scope, Filter; fehlendes
   Recht: Strategie, Mapper, Cache, Ausstellungszeitpunkt. Konkrete Befehle je Stufe.
5. `## Rücknahme und Reset`: `Reset-Team.ps1 -Team 01`, `apply-solution.sh` Befehle, Sessions beenden.
6. `## Ersatz mit OpenLDAP`: welche Versuche laufen, welche nur besprochen werden, mit Verweis auf
   aufgezeichnete Ergebnisse aus dem Probelauf.
7. `## Abbau`: `Remove-Workshop.ps1 -PlanOnly`, dann ohne; Prüfliste danach.

- [ ] **Step 1: Dateien schreiben.**
- [ ] **Step 2: Prüfen** `pre-commit run --all-files` (markdownlint, yamllint, lychee).
- [ ] **Step 3: Commit** `docs(workshops): add task, trainer guide and README for the AD unit`

---

### Task 15: Probelauf auf GCP (nach Freigabe)

**Files:**

- Modify: `workshops/active-directory/trainer.md` (beobachtete Ergebnisse), gegebenenfalls Skripte
  und `aufgabe.md` bei belegten Abweichungen.
- Nicht versioniert: `.run/manifest.json`, `.run/report-*.json`, `.run/secrets/`.

Voraussetzung: Freigabe von Projekt, Zone, Quell-IPs, Trainer-Principal, Ablaufzeitpunkt und Budget.

- [ ] **Step 1:** `New-Workshop.ps1 -PlanOnly` mit den freigegebenen Werten; Ausgabe prüfen.
- [ ] **Step 2:** `New-Workshop.ps1` ohne PlanOnly; Manifest lesen; `.run/secrets/wsadmin.json` vorhanden.
- [ ] **Step 3:** IAP-Tunnel und RDP; `Initialize-Domain.ps1` bis Phase `ready`; Anmeldung als
  `MUSTERTECH\Administrator`; `Protect-Workshop.ps1`; Neustart der VM und erneute Anmeldung.
- [ ] **Step 4:** `Initialize-Workshop.ps1 -CertificateValidUntil <Workshop-Ende + 1 Tag>`;
  `workshop-ca.crt`, `workshop-ad.json` und `team<NN>.json` nach `.run/` beziehungsweise `lab/certs/` kopieren.
- [ ] **Step 5:** `Test-Workshop.ps1 -Mode Guest` auf dem DC, `Test-Workshop.ps1 -Mode Trainer -IncludeIap`
  lokal; alle Prüfungen PASS, Bericht ablegen.
- [ ] **Step 6:** Alle sechs Versuche aus `aufgabe.md` für Team01 in Bash und für Team02 in PowerShell
  praktisch durchspielen; Beobachtungen zu verschobenem Benutzer, Refresh, SSO und Token-Zeiten mit `iat`/
  `exp` in `trainer.md` eintragen. Abweichungen zwischen Spec und Beobachtung als Beobachtung dokumentieren.
- [ ] **Step 7:** `Reset-Team.ps1` für beide Teams; `Test-Workshop.ps1 -Mode Trainer` erneut PASS.
- [ ] **Step 8:** VM neu starten, LDAPS-Prüfung T06 erneut.
- [ ] **Step 9:** Commit der belegten Änderungen: `docs(workshops): record the observed AD workshop behaviour`
- [ ] **Step 10:** Abbau erst nach Absprache: `Remove-Workshop.ps1 -PlanOnly`, dann `Remove-Workshop.ps1`;
  danach `gcloud compute instances list`, `disks list`, `addresses list`, `firewall-rules list`, `networks list`
  mit `--filter=name~'^kcad-'` leer; IAP-Policy ohne Workshop-Binding.

---

### Task 16: Abschluss

- [ ] `pre-commit run --all-files`, Pester für alle Tests, PSScriptAnalyzer ohne Befund.
- [ ] Diff gegen `origin/main` lesen; keine Geheimnisse, keine Aufgabenmarker, keine Maschinennamen außer
  den fiktiven Workshop-Namen.
- [ ] `git push -u origin codex/ad-workshop-spec`, PR mit `gh pr create` (Problem, Verhalten, geprüft),
  CI abwarten, nicht mergen.

---

## Self-Review

**Spec-Abdeckung:** Verzeichnisdienst und Architektur (Tasks 6, 9, 10), Netzwerk und TLS (6, 10, 12),
Datenmodell und Delegation (10, 12), Keycloak und Anwendung (2, 3, 13), Ablauf und Ergebnisse (14, 15),
Ablage und Schnittstellen (1 bis 14), Kosten (14 README, Freigabe vor 15), Abnahme (12, 15), Abbau (8, 15).
Offen bleibt die Bestätigung des Keycloak-Verhaltens bei verschobenem und deaktiviertem Benutzer, die nur
der Probelauf liefert; die Doku verspricht deshalb keine stabile Keycloak-ID.

**Typkonsistenz:** Manifest-Schlüssel `resources.network|subnet|firewallLdaps|firewallIapRdp|internalAddress|
externalAddress|dataDisk|instance` werden in Task 6, 7, 8 und 12 gleich verwendet; `iamBindings[]` mit
`principal, role, conditionTitle, instanceId`; Ressourcennamen ausschließlich aus `Get-WorkshopResourceNames`.
