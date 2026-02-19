# Modul 07c: LDAP Federation

## Übungsziel

Am Ende dieser Übung hast du:

- Einen **LDAP-Verzeichnisdienst** (OpenLDAP) als externe Benutzerquelle
  erkundet
- **User Federation** in Keycloak konfiguriert, um LDAP-Benutzer zu importieren
- Einen **Gruppen-Mapper** eingerichtet, der LDAP-Gruppen nach Keycloak
  synchronisiert
- LDAP-Gruppen auf **Keycloak Realm Roles** gemappt
- Rollen-Claims in **OIDC-Tokens** überprüft

**Geschätzte Dauer:** 30 Minuten

---

## Umgebung starten

```bash
cd assignments/modul-07c-ldap-federation
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe
> diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details
> siehe
> [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

Warte bis alle Services bereit sind (~60 Sekunden). Der Realm "mustertech" wird
automatisch importiert. Prüfe den Setup-Container:

```bash
docker compose logs -f assignment-setup
# -> "=== Setup complete ===" abwarten, dann Ctrl+C
```

### Architektur

```
Browser --> Keycloak (Port 8080) --> PostgreSQL
                |
                +--> OpenLDAP (Port 1389)
```

| Service                  | URL / Adresse                    | Zugangsdaten                             |
|:-------------------------|:---------------------------------|:-----------------------------------------|
| Keycloak Admin-Konsole   | <http://localhost:8080>          | `admin` / `admin`                        |
| OpenLDAP (Docker-intern) | `ldap://assignment-openldap:389` | `cn=admin,dc=mustertech,dc=de` / `admin` |
| OpenLDAP (Host)          | `ldap://localhost:1389`          | `cn=admin,dc=mustertech,dc=de` / `admin` |

### LDAP-Verzeichnisstruktur

```
dc=mustertech,dc=de
├── ou=users
│   ├── uid=hans.mueller    (Hans Mueller, Entwicklung)
│   ├── uid=anna.schmidt    (Anna Schmidt, Vertrieb)
│   └── uid=max.admin       (Max Administrator, Management)
└── ou=groups
    ├── cn=entwicklung      (Mitglied: hans.mueller)
    ├── cn=vertrieb         (Mitglied: anna.schmidt)
    └── cn=management       (Mitglied: max.admin)
```

### Testbenutzer (im LDAP)

| User           | Passwort   | LDAP-Gruppe   |
|:---------------|:-----------|:--------------|
| `hans.mueller` | `test1234` | `entwicklung` |
| `anna.schmidt` | `test1234` | `vertrieb`    |
| `max.admin`    | `test1234` | `management`  |

> **Ausgangslage:** Die Benutzer existieren **nur im LDAP**. In Keycloak gibt es
> noch keine Benutzer im Realm "mustertech" - diese werden über die User Federation
synchronisiert. Die Realm Roles `entwicklung`, `vertrieb` und `management` sind bereits angelegt.

---

## Teil 1: LDAP-Verzeichnis erkunden

### Schritt 1.1: LDAP-Baum anzeigen

Verwende `ldapsearch` im OpenLDAP-Container, um den LDAP-Baum zu erkunden:

```bash
docker exec assignment-openldap ldapsearch -x \
  -H ldap://localhost \
  -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "dc=mustertech,dc=de" \
  "(objectClass=*)" dn
```

> **Erklärung der Parameter:**
>
> | Parameter | Bedeutung                          |
> |:----------|:-----------------------------------|
> | `-x`      | Simple Authentication (nicht SASL) |
> | `-H`      | LDAP-Server URL                    |
> | `-D`      | Bind DN (Admin-Account)            |
> | `-w`      | Passwort                           |
> | `-b`      | Base DN (Startpunkt der Suche)     |

### Schritt 1.2: Benutzer anzeigen

```bash
docker exec assignment-openldap ldapsearch -x \
  -H ldap://localhost \
  -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "ou=users,dc=mustertech,dc=de" \
  "(objectClass=inetOrgPerson)"
```

Beachte die Attribute jedes Benutzers: `uid`, `cn`, `sn`, `givenName`, `mail`.

### Schritt 1.3: Gruppen anzeigen

```bash
docker exec assignment-openldap ldapsearch -x \
  -H ldap://localhost \
  -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "ou=groups,dc=mustertech,dc=de" \
  "(objectClass=groupOfNames)"
```

Beachte das `member`-Attribut - es enthält den **vollständigen DN** der
Gruppenmitglieder.

> **Konzept: LDAP-Gruppentypen** - LDAP unterstützt verschiedene Gruppen-Typen.
> `groupOfNames` ist der gängigste und speichert Mitgliedschaften als vollständige DNs.
> Keycloak unterstützt zusätzlich `posixGroup` (mit `memberUid`) und `groupOfUniqueNames` (mit `uniqueMember`).

---

## Teil 2: User Federation konfigurieren

### Schritt 2.1: LDAP-Provider hinzufügen

1. Öffne die Keycloak Admin-Konsole: <http://localhost:8080>
2. Wähle den Realm **mustertech**
3. Navigiere zu **User federation**
4. Klicke auf **Add LDAP providers**

### Schritt 2.2: Verbindungseinstellungen konfigurieren

Konfiguriere die folgenden Einstellungen:

**General options:**

| Feld            | Wert              |
|:----------------|:------------------|
| UI display name | `mustertech-ldap` |
| Vendor          | `Other`           |

**Connection and authentication settings:**

| Feld             | Wert                             |
|:-----------------|:---------------------------------|
| Connection URL   | `ldap://assignment-openldap:389` |
| Bind type        | `simple`                         |
| Bind DN          | `cn=admin,dc=mustertech,dc=de`   |
| Bind credentials | `admin`                          |

Klicke auf **Test connection** - es sollte "Successfully connected to LDAP" erscheinen.

Klicke weiter unten auf **Test authentication** - es sollte "Successfully connected to LDAP" erscheinen.

**LDAP searching and updating:**

| Feld                    | Wert                           |
|:------------------------|:-------------------------------|
| Edit mode               | `READ_ONLY`                    |
| Users DN                | `ou=users,dc=mustertech,dc=de` |
| Username LDAP attribute | `uid`                          |
| RDN LDAP attribute      | `uid`                          |
| UUID LDAP attribute     | `entryUUID`                    |
| User object classes     | `inetOrgPerson`                |
| Search scope            | `One Level`                    |

**Sync settings:**

| Feld               | Wert  |
|:-------------------|:------|
| Import users       | `ON`  |
| Sync Registrations | `OFF` |

Klicke **Save**.

> **Konzept: Edit Mode** - `READ_ONLY` bedeutet, dass Keycloak die LDAP-Daten
> nicht verändern kann. Passwort-Änderungen und Profil-Updates müssen direkt im LDAP erfolgen.
> Im Modus `WRITABLE` könnten Änderungen in Keycloak zurück ins LDAP geschrieben werden.

---

## Teil 3: Benutzer synchronisieren und testen

### Schritt 3.1: Vollständige Synchronisation ausführen

1. Gehe in die Einstellungen von `mustertech-ldap` und klicke im oberen Bereich auf **Action** -> **Sync all users**
2. Es sollte eine Meldung erscheinen, dass 3 Benutzer importiert/aktualisiert wurden

### Schritt 3.2: Importierte Benutzer prüfen

1. Navigiere zu **Users**
2. Klicke auf **View all users** und suche nach `*`

Die drei LDAP-Benutzer sollten jetzt sichtbar sein: `hans.mueller`,
`anna.schmidt`, `max.admin`.

3. Klicke auf **hans.mueller** und prüfe:
    - Die Attribute (Vorname, Nachname, E-Mail) wurden aus dem LDAP übernommen
    - Das Feld **Federation link** zeigt `mustertech-ldap` an

### Schritt 3.3: Login testen

1. Öffne ein neues **privates Browserfenster**
2. Gehe zu <http://localhost:8080/realms/mustertech/account/>
3. Melde dich an mit:
    - Username: `hans.mueller`
    - Passwort: `test1234`

**Erwartetes Ergebnis:** Der Login funktioniert - Keycloak authentifiziert den Benutzer gegen das LDAP-Verzeichnis.

---

## Teil 4: Gruppen-Mapper konfigurieren

### Schritt 4.1: Gruppen-Mapper anlegen

1. Navigiere zu **User federation** -> **mustertech-ldap**
2. Wechsle zum Tab **Mappers**
3. Klicke auf **Add mapper**
4. Konfiguriere:

| Feld                                 | Wert                              |
|:-------------------------------------|:----------------------------------|
| Name                                 | `group-mapper`                    |
| Mapper type                          | `group-ldap-mapper`               |
| LDAP Groups DN                       | `ou=groups,dc=mustertech,dc=de`   |
| Group Name LDAP Attribute            | `cn`                              |
| Group Object Classes                 | `groupOfNames`                    |
| Membership LDAP Attribute            | `member`                          |
| Membership Attribute Type            | `DN`                              |
| Membership User LDAP Attribute       | `uid`                             |
| Mode                                 | `READ_ONLY`                       |
| User Groups Retrieve Strategy        | `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE` |
| Drop non-existing groups during sync | `ON`                              |

5. Klicke **Save**

> **Konzept: Group-LDAP-Mapper** - Der Mapper synchronisiert LDAP-Gruppen als
> Keycloak-Gruppen. Die Mitgliedschaft wird über das `member`-Attribut aufgelöst, das den
> vollständigen DN des Benutzers enthält. Im `READ_ONLY`-Modus können Gruppenmitgliedschaften nur
> im LDAP geändert werden.

### Schritt 4.2: Gruppen synchronisieren

1. Gehe in die Einstellungen des neuen Mappers.
2. Klicke im oberen Bereich der Mapper-Seite auf auf **Action** -> **Sync LDAP groups to Keycloak**

### Schritt 4.3: Gruppen in Keycloak prüfen

1. Navigiere zu **Groups**
2. Du siehst jetzt die drei LDAP-Gruppen: `entwicklung`, `vertrieb`,
   `management`
3. Klicke auf **entwicklung** -> Tab **Members**
4. `hans.mueller` sollte als Mitglied aufgelistet sein

Prüfe auch die anderen Gruppen:

| Gruppe        | Erwartetes Mitglied |
|:--------------|:--------------------|
| `entwicklung` | `hans.mueller`      |
| `vertrieb`    | `anna.schmidt`      |
| `management`  | `max.admin`         |

---

## Teil 5: Gruppen auf Realm Roles mappen

Im Realm "mustertech" existieren bereits drei Rollen: `entwicklung`, `vertrieb`
und `management`. Jetzt verknüpfst du die synchronisierten LDAP-Gruppen mit
diesen Rollen.

### Schritt 5.1: Rollen den Gruppen zuweisen

1. Navigiere zu **Groups** -> **entwicklung**
2. Wechsle zum Tab **Role mapping**
3. Klicke auf **Assign role**
4. Wähle die Realm Role **entwicklung** und klicke **Assign**

Wiederhole für die anderen Gruppen:

| Gruppe        | Zuzuweisende Realm Role |
|:--------------|:------------------------|
| `entwicklung` | `entwicklung`           |
| `vertrieb`    | `vertrieb`              |
| `management`  | `management`            |

### Schritt 5.2: Rollen-Zuweisung prüfen

1. Navigiere zu **Users** -> **hans.mueller**
2. Wechsle zum Tab **Role mapping**
3. Die Rolle `entwicklung` ist jetzt zugewiesen (über die Gruppe)

> **Indirekte Rollenzuweisung** - Benutzer erhalten Rollen nicht direkt,
> sondern über ihre Gruppenmitgliedschaft. Wenn ein neuer Benutzer im LDAP der
> Gruppe "entwicklung" hinzugefügt wird, erhält er nach der nächsten
> Synchronisation automatisch die Keycloak-Rolle "entwicklung".

---

## Teil 6: Rollen-Claims in Tokens überprüfen

### Schritt 6.1: Token über die Evaluate-Funktion prüfen

1. Navigiere zu **Clients** -> **test-app** -> Tab **Client scopes**
2. Klicke auf den Sub-Tab **Evaluate**
3. Wähle bei **Users** den Benutzer **hans.mueller**
4. Klicke auf **Generated access token**

Suche im Token nach dem Abschnitt `realm_access`:

```json
{
  "realm_access": {
    "roles": [
      "entwicklung",
      "default-roles-mustertech"
    ]
  }
}
```

**Erwartetes Ergebnis:** Die Rolle `entwicklung` erscheint im Token, weil
`hans.mueller` über die LDAP-Gruppe "entwicklung" diese Keycloak-Rolle
erhalten hat.

### Schritt 6.2: Verschiedene Benutzer vergleichen

Wiederhole die Evaluate-Funktion für `anna.schmidt` und `max.admin`:

| Benutzer       | Erwartete Rolle in `realm_access.roles` |
|:---------------|:----------------------------------------|
| `hans.mueller` | `entwicklung`                           |
| `anna.schmidt` | `vertrieb`                              |
| `max.admin`    | `management`                            |

### Schritt 6.3: Token per curl abrufen

Du kannst auch direkt ein Token per **Direct Access Grant** (Resource Owner Password Credentials) abrufen:

```bash
curl -s -X POST http://localhost:8080/realms/mustertech/protocol/openid-connect/token \
  -d "client_id=test-app" \
  -d "grant_type=password" \
  -d "username=hans.mueller" \
  -d "password=test1234" | python3 -m json.tool
```

```powershell
$uri = "http://localhost:8080/realms/mustertech/protocol/openid-connect/token"
$response = Invoke-RestMethod -Method Post -Uri $uri -Body @{
    client_id  = "test-app"
    grant_type = "password"
    username   = "hans.mueller"
    password   = "test1234"
}
$response | ConvertTo-Json -Depth 5
```

### Schritt 6.4: Token dekodieren

Kopiere den `access_token` aus der Antwort und dekodiere den Payload (mittlerer
Teil des JWT):

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/realms/mustertech/protocol/openid-connect/token \
  -d "client_id=test-app" \
  -d "grant_type=password" \
  -d "username=hans.mueller" \
  -d "password=test1234" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

```powershell
$uri = "http://localhost:8080/realms/mustertech/protocol/openid-connect/token"
$response = Invoke-RestMethod -Method Post -Uri $uri -Body @{
    client_id  = "test-app"
    grant_type = "password"
    username   = "hans.mueller"
    password   = "test1234"
}
$payload = $response.access_token.Split('.')[1]
# Base64-URL-Padding korrigieren
switch ($payload.Length % 4) { 2 { $payload += '==' } 3 { $payload += '=' } }
$bytes = [Convert]::FromBase64String($payload.Replace('-','+').Replace('_','/'))
[System.Text.Encoding]::UTF8.GetString($bytes) |
    ConvertFrom-Json | ConvertTo-Json -Depth 5
```

Prüfe, dass `realm_access.roles` die Rolle `entwicklung` enthält.

---

## Teil 7: Gruppen-Claim hinzufügen (Bonus)

Zusätzlich zu den Rollen kannst du auch die **Gruppenmitgliedschaft** direkt als
eigenen Claim im Token verfügbar machen.

### Schritt 7.1: Client Scope erstellen

1. Navigiere zu **Client scopes** -> **Create client scope**
2. Konfiguriere:
    - Name: `groups`
    - Type: `Optional`
    - Protocol: `OpenID Connect`
3. Klicke **Save**

### Schritt 7.2: Group Membership Mapper anlegen

1. Wechsle zum Tab **Mappers** -> **Configure a new mapper** -> **Group
   Membership**
2. Konfiguriere:

| Feld                | Wert     |
|:--------------------|:---------|
| Name                | `groups` |
| Token Claim Name    | `groups` |
| Full group path     | `OFF`    |
| Add to ID token     | `ON`     |
| Add to access token | `ON`     |
| Add to userinfo     | `ON`     |

3. Klicke **Save**

### Schritt 7.3: Scope dem Client zuweisen

1. Navigiere zu **Clients** -> **test-app** -> Tab **Client scopes**
2. Klicke auf **Add client scope**
3. Wähle **groups** und füge ihn als **Default** hinzu

### Schritt 7.4: Ergebnis prüfen

Teste erneut mit der Evaluate-Funktion (Schritt 6.1). Der Token enthält jetzt
zusätzlich:

```json
{
  "groups": [
    "entwicklung"
  ],
  "realm_access": {
    "roles": [
      "entwicklung",
      "default-roles-mustertech"
    ]
  }
}
```

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Den **LDAP-Verzeichnisdienst** mit Benutzern und Gruppen erkundet
- [x] **User Federation** mit OpenLDAP in Keycloak konfiguriert
- [x] LDAP-Benutzer nach Keycloak **synchronisiert** und Login getestet
- [x] Einen **Gruppen-Mapper** eingerichtet, der LDAP-Gruppen synchronisiert
- [x] LDAP-Gruppen auf **Keycloak Realm Roles** gemappt
- [x] Rollen-Claims in **OIDC-Tokens** überprüft
- [x] (Bonus) Einen **Gruppen-Claim** im Token konfiguriert

## Troubleshooting

Häufige Probleme und Lösungen findest du in der zentralen
[Troubleshooting-Anleitung](../TROUBLESHOOTING.md).

### LDAP-Verbindung schlägt fehl

- Prüfe, ob der OpenLDAP-Container läuft: `docker compose ps`
- Teste die Verbindung manuell:

  ```bash
  docker exec assignment-openldap ldapsearch -x \
    -H ldap://localhost \
    -D "cn=admin,dc=mustertech,dc=de" -w admin \
    -b "dc=mustertech,dc=de" -s base
  ```

- Stelle sicher, dass die Connection URL `ldap://assignment-openldap:389`
  verwendet
  (nicht `localhost` - Keycloak läuft im Docker-Netzwerk)

### Keine Benutzer nach Synchronisation

- Prüfe den **Users DN**: muss `ou=users,dc=mustertech,dc=de` sein
- Prüfe **User Object Classes**: muss `inetOrgPerson` sein
- Prüfe **Search Scope**: `One Level` für die flache Verzeichnisstruktur

### Gruppen werden nicht synchronisiert

- Prüfe den **LDAP Groups DN**: muss `ou=groups,dc=mustertech,dc=de` sein
- Prüfe **Group Object Classes**: muss `groupOfNames` sein
- Prüfe **Membership LDAP Attribute**: muss `member` sein
- Stelle sicher, dass nach dem Anlegen des Mappers eine erneute
  User-Synchronisation durchgeführt wurde
