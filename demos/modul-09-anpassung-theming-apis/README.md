# Live-Demo: Modul 09 -- Anpassung, Theming & APIs

Custom Theme zeigen und die Admin REST API live nutzen -- User erstellen, auflisten und Clients abfragen.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Custom Theme zeigen | 3 Min |
| Demo 2 | Admin REST API: Token holen | 2 Min |
| Demo 3 | Admin REST API: User verwalten | 4 Min |
| Demo 4 | Admin REST API: Clients abfragen | 3 Min |

## Voraussetzungen

- Docker / Podman (Container-Runtime)
- curl, jq (für API-Demos)

## Setup

```bash
# 1. Keycloak + Postgres starten (Port 9090)
docker compose up -d

# 2. Warten bis Keycloak bereit ist (~30 s)
docker compose logs -f demo-keycloak
# -> "Keycloak ... started in ..." abwarten, dann Ctrl+C
```

Keycloak Admin-Konsole: <http://localhost:9090> (admin / admin)

Der Realm **mustertech** wird automatisch importiert mit:

- Login Theme: `mustertech` (Custom Theme)
- User `alice` / `demo1234`
- User `bob` / `demo1234`

---

## Demo 1: Custom Theme zeigen

### Schritt 1 -- Login-Seite öffnen

1. Öffne ein **Inkognito-Fenster**
2. Navigiere zu: <http://localhost:9090/realms/mustertech/account>
3. Die Login-Seite zeigt das **Mustertech-Theme** (eigenes Logo, Farben, Texte)

> **Zeigen:** Der Realm nutzt das Theme `mustertech`, das per Volume in den Container
> gemountet wird. Kein Custom Docker Image nötig.

### Schritt 2 -- Theme-Struktur erklären

Die Dateistruktur des Themes:

```text
themes/mustertech/
+-- login/
|   +-- theme.properties          (Parent-Theme, CSS-Import)
|   +-- resources/
|   |   +-- css/mustertech.css    (Eigene Styles)
|   |   +-- img/logo.png          (Firmenlogo)
|   |   +-- img/bg.png            (Hintergrundbild)
|   +-- messages/
|       +-- messages_de.properties (Deutsche Texte)
+-- email/
    +-- theme.properties
    +-- html/template.ftl          (HTML-E-Mail-Template)
    +-- html/password-reset.ftl    (Passwort-Reset-E-Mail)
    +-- text/password-reset.ftl    (Text-Variante)
```

> **Zeigen:** Ein Theme besteht aus `theme.properties` (Konfiguration), Resources (CSS,
> Bilder) und Messages (Übersetzungen). Man erweitert immer ein Parent-Theme
> (`keycloak.v2`).

### Schritt 3 -- Theme wechseln (Optional)

1. Wechsle zur Admin-Konsole
2. Navigiere zu **Realm settings** -> **Themes**
3. Ändere **Login theme** auf `keycloak` (Standard)
4. Klicke auf **Save**
5. Lade die Login-Seite neu -- das Standard-Theme erscheint
6. Wechsle zurück auf `mustertech`

**Diskussionspunkte:**

- Wie deployed man Themes in Produktion? (Docker Volume oder Custom Image)
- Kann man Themes pro Client setzen? (Ja, über Client-Einstellungen)

---

## Demo 2: Admin REST API -- Token holen

Bevor wir die API nutzen können, brauchen wir ein Admin-Token.

### Schritt 1 -- Token via curl abrufen

```bash
TOKEN=$(curl -sf -X POST http://localhost:9090/realms/master/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" | jq -r '.access_token')

echo "${TOKEN}"
```

> **Zeigen:** Wir authentifizieren uns gegen den **master**-Realm mit dem `admin-cli`-Client.
> Das Token berechtigt zu allen Admin-Operationen.

### Schritt 2 -- Token prüfen

```bash
curl -sf http://localhost:9090/realms/master/protocol/openid-connect/userinfo \
  -H "Authorization: Bearer ${TOKEN}" | jq .
```

---

## Demo 3: Admin REST API -- User verwalten

### Schritt 1 -- Alle User auflisten

```bash
curl -sf http://localhost:9090/admin/realms/mustertech/users \
  -H "Authorization: Bearer ${TOKEN}" | jq '.[].username'
```

**Erwartete Ausgabe:** `alice`, `bob`

### Schritt 2 -- Neuen User erstellen

```bash
curl -sf -X POST http://localhost:9090/admin/realms/mustertech/users \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "api-user",
    "enabled": true,
    "email": "api-user@example.com",
    "firstName": "API",
    "lastName": "User",
    "emailVerified": true,
    "credentials": [{
      "type": "password",
      "value": "demo1234",
      "temporary": false
    }]
  }'
```

### Schritt 3 -- User prüfen

```bash
curl -sf http://localhost:9090/admin/realms/mustertech/users \
  -H "Authorization: Bearer ${TOKEN}" | jq '.[].username'
```

**Erwartete Ausgabe:** `alice`, `api-user`, `bob`

> **Zeigen:** Der User wurde per API erstellt -- ohne die Admin-Konsole zu benutzen. Das ist
> die Grundlage für Automatisierung (Provisioning, CI/CD).

### Schritt 4 -- User in Admin-Konsole zeigen

1. Wechsle zur Admin-Konsole
2. Navigiere zu **Users**
3. Der User `api-user` ist sichtbar

**Diskussionspunkte:**

- Wann API statt Admin-Konsole? (Automatisierung, Bulk-Operationen, CI/CD)
- Wie sichert man den API-Zugang in Produktion? (Service Account, nicht admin-cli)

---

## Demo 4: Admin REST API -- Clients abfragen

### Schritt 1 -- Alle Clients auflisten

```bash
curl -sf http://localhost:9090/admin/realms/mustertech/clients \
  -H "Authorization: Bearer ${TOKEN}" | jq '.[].clientId'
```

> **Zeigen:** Neben den selbst erstellten Clients gibt es zahlreiche Built-in Clients
> (`account`, `admin-cli`, `realm-management`, etc.).

### Schritt 2 -- Client-Details abfragen

```bash
CLIENT_UUID=$(curl -sf http://localhost:9090/admin/realms/mustertech/clients \
  -H "Authorization: Bearer ${TOKEN}" | jq -r '.[] | select(.clientId=="account") | .id')

curl -sf http://localhost:9090/admin/realms/mustertech/clients/${CLIENT_UUID} \
  -H "Authorization: Bearer ${TOKEN}" | jq '{clientId, enabled, protocol, publicClient}'
```

**Diskussionspunkte:**

- Welche API-Endpunkte gibt es noch? (Roles, Groups, Identity Providers, ...)
- Wo findet man die API-Dokumentation? (Keycloak REST API Docs)

---

## Aufräumen

```bash
docker compose down -v
```
