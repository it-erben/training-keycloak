# Live-Demo Modul 06d: Client Role Isolation mit Protocol Mappern

Standardmäßig enthalten Keycloak-Tokens im `resource_access`-Claim die Client Roles **aller** Clients,
bei denen ein Benutzer Rollen hat. Das ist ein Datenschutz-/Sicherheitsproblem: Die CRM-App sieht
HR-Rollen von Charlie und umgekehrt. Diese Demo zeigt, wie man mit scoped
`oidc-usermodel-client-role-mapper` Mappern sicherstellt, dass jeder Client nur seine eigenen Rollen
in einem flachen `roles`-Claim sieht.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Das Problem: Token enthält alle Client Roles | 3 Min |
| Demo 2 | Die Lösung: Scoped Client Scopes | 4 Min |
| Demo 3 | Token per CLI verifizieren | 3 Min |

## Voraussetzungen

- Docker / Podman (Container-Runtime)

## Setup

```bash
# 1. Keycloak + Postgres starten (Port 9090)
docker compose up -d

# 2. Warten bis Setup abgeschlossen ist (~60 s)
docker compose logs -f demo-setup
# -> "=== Setup complete ===" abwarten, dann Ctrl+C
```

Keycloak Admin-Konsole: <http://localhost:9090> (admin / admin)

Der Realm **mustertech** wird automatisch importiert. Die Client Scopes `crm-roles` und `hr-roles`
werden vom Setup-Container erstellt.

### Testbenutzer

| User | Passwort | CRM-Rollen | HR-Rollen |
| :--- | :--- | :--- | :--- |
| `alice` | `demo1234` | `crm-editor`, `crm-viewer` | keine |
| `bob` | `demo1234` | keine | `hr-editor`, `hr-viewer` |
| `charlie` | `demo1234` | `crm-viewer` | `hr-viewer`, `hr-admin` |

**Charlie** ist der Schlüssel-Testuser: er hat Rollen in **beiden** Clients.

---

## Demo 1: Das Problem (~3 Min)

Charlies Token von der CRM-App enthält auch seine HR-Rollen. Die CRM-App sieht Daten, die sie nichts angehen.

### Schritt 1: Token evaluieren

1. Navigiere zu **Clients** -> **crm-app** -> Tab **Client scopes**
2. Klicke auf **Evaluate**
3. Wähle **User:** `charlie`
4. Klicke auf **Generated access token**

### Schritt 2: resource_access analysieren

Suche den Claim `resource_access`:

```json
"resource_access": {
  "crm-app": {
    "roles": ["crm-viewer"]
  },
  "hr-app": {
    "roles": ["hr-viewer", "hr-admin"]
  }
}
```

> **Zeigen:** Die CRM-App erhält Charlies HR-Rollen (`hr-viewer`, `hr-admin`) im Token.
> Das ist ein Verstoß gegen das Least-Privilege-Prinzip.

**Diskussionspunkte:**

- Warum ist das ein Problem? (Datenschutz, Token-Bloat, Attack Surface)
- Was passiert bei 20 Microservices mit je 5 Rollen?

---

## Demo 2: Die Lösung (~4 Min)

Wir haben per Setup-Container für jeden Client einen eigenen Client Scope mit einem scoped Role Mapper erstellt.

### Schritt 1: Client Scope inspizieren

1. Navigiere zu **Client scopes** -> **crm-roles**
2. Wechsle zum Tab **Mappers**
3. Klicke auf **crm-role-mapper**

Zeige die Konfiguration:

| Feld | Wert |
| :--- | :--- |
| Client ID | `crm-app` |
| Token Claim Name | `roles` |
| Multivalued | ON |
| Add to access token | ON |

> **Zeigen:** Der Mapper ist auf `clientId = crm-app` eingeschränkt, er gibt nur CRM-Rollen aus.

### Schritt 2: Token erneut evaluieren (crm-app)

1. Navigiere zu **Clients** -> **crm-app** -> Tab **Client scopes**
2. Klicke auf **Evaluate** -> **User:** `charlie`
3. Klicke auf **Generated access token**

Suche den neuen Claim `roles`:

```json
"roles": ["crm-viewer"]
```

> **Zeigen:** Der flache `roles`-Claim enthält nur CRM-Rollen. Keine HR-Rollen sichtbar.

### Schritt 3: Vergleich: hr-app

1. Navigiere zu **Clients** -> **hr-app** -> Tab **Client scopes**
2. Klicke auf **Evaluate** -> **User:** `charlie`
3. Klicke auf **Generated access token**

```json
"roles": ["hr-viewer", "hr-admin"]
```

> **Zeigen:** Gleicher User, anderer Client, andere Rollen im `roles`-Claim.

**Diskussionspunkte:**

- Wiederverwendbarkeit: Jeder neue Client bekommt seinen eigenen Scope
- Flach vs. verschachtelt: `roles` ist einfacher zu parsen als `resource_access.crm-app.roles`
- Spring Security: `roles`-Claim lässt sich direkt als Granted Authorities mappen

---

## Demo 3: Token per CLI (~3 Min)

Wir verifizieren die Isolation mit echten Tokens.

### Schritt 1: CRM Token für Charlie

```bash
curl -s -X POST http://localhost:9090/realms/mustertech/protocol/openid-connect/token \
  -d "grant_type=password&client_id=crm-app&client_secret=crm-app-secret&username=charlie&password=demo1234" \
  | jq -r '.access_token' | jq -R 'split(".") | .[1] | @base64d | fromjson | .roles'
```

Erwartete Ausgabe:

```json
["crm-viewer"]
```

### Schritt 2: HR Token für Charlie

```bash
curl -s -X POST http://localhost:9090/realms/mustertech/protocol/openid-connect/token \
  -d "grant_type=password&client_id=hr-app&client_secret=hr-app-secret&username=charlie&password=demo1234" \
  | jq -r '.access_token' | jq -R 'split(".") | .[1] | @base64d | fromjson | .roles'
```

Erwartete Ausgabe:

```json
["hr-viewer", "hr-admin"]
```

### Schritt 3: resource_access zeigen

```bash
curl -s -X POST http://localhost:9090/realms/mustertech/protocol/openid-connect/token \
  -d "grant_type=password&client_id=crm-app&client_secret=crm-app-secret&username=charlie&password=demo1234" \
  | jq -r '.access_token' | jq -R 'split(".") | .[1] | @base64d | fromjson | .resource_access'
```

> **Zeigen:** `resource_access` enthält weiterhin alle Rollen beider Clients, das liegt an
> `fullScopeAllowed: true`. Der scoped Mapper **ergänzt** den flachen `roles`-Claim,
> entfernt aber nichts aus `resource_access`.

**Diskussionspunkte:**

- Soll man `resource_access` entfernen? (Eigenen Mapper mit "Remove from access token" konfigurieren)
- Spring Security: Welchen Claim nutzt man? (`roles` vs. `resource_access`)
- `fullScopeAllowed: false` als Alternative, dann erscheinen nur zugewiesene Scopes

---

## Aufräumen

```bash
docker compose down -v
```
