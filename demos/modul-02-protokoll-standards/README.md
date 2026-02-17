# Live-Demos: Modul 02 - Protokoll-Standards

Zwei Live-Demos, die OAuth 2.0 / OIDC aus den Folien zu zeigen.

| Demo   | Flow                           | Bezug                     |
|:-------|:-------------------------------|:--------------------------|
| Demo 1 | OIDC Authorization Code + PKCE | Folien 2.2, 3.3, 3.4, 3.5 |
| Demo 2 | Client Credentials             | Folien 2.4, 3.1           |

## Voraussetzungen

- Docker / Podman (Container-Runtime)
- Postman (Desktop-App)
- Browser

## Setup

```bash
# 1. Keycloak + Postgres starten (Port 9090)
docker compose up -d

# 2. Warten bis Keycloak bereit ist (~30 s)
docker compose logs -f demo-keycloak
# → "Keycloak ... started in ..." abwarten, dann Ctrl+C

# 3. Postman Collection importieren
#    File → Import → Keycloak-Modul02-Demos.postman_collection.json
```

Keycloak Admin-Konsole: <http://localhost:9090> (admin / admin)

---

## Demo 1: OIDC Discovery & Authorization Code Flow

### Schritt 1 — Discovery Endpoint (Browser)

URL im Browser öffnen:

```text
http://localhost:9090/realms/demo/.well-known/openid-configuration
```

**Zeigen:** `authorization_endpoint`, `token_endpoint`,
`supported_scopes`, `grant_types_supported`, `id_token_signing_alg_values_supported`.

> Alternativ: In Postman den Request "Discovery Endpoint" absenden.

### Schritt 2 — Authorization Request (Browser)

Auth-URL manuell im Browser aufrufen (PKCE-Werte sind Beispiele). Die URL ist umbrochen,
bitte beim Kopieren die Zeilen zusammenfügen:

```text
http://localhost:9090/realms/demo/protocol/openid-connect/auth?response_type=code&
client_id=demo-spa&redirect_uri=https%3A%2F%2Foauth.pstmn.io%2Fv1%2Fcallback&
scope=openid%20profile%20email&state=demo123&
code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&
code_challenge_method=S256
```

> **Hinweis:** Der `code_challenge` oben passt zum `code_verifier`
> `dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk` (RFC 7636 Beispiel).

### Schritt 3 — Login

Keycloak zeigt das Login-Formular. Einloggen mit:

- **Username:** `demo`
- **Password:** `demo`

### Schritt 4 — Code aus Redirect kopieren

Nach dem Login leitet Keycloak weiter. Den `code`-Parameter aus der
URL kopieren.

### Schritt 5 — Token Request (Postman)

In Postman den Request **"Token Exchange (Auth Code + PKCE)"** öffnen.

**Variante A — Postman OAuth-2.0-Tab (empfohlen):**

1. Tab "Authorization" → Type: OAuth 2.0
2. "Get New Access Token" klicken
3. Postman öffnet den Browser, Login mit `demo` / `demo`
4. Token wird automatisch eingetauscht und angezeigt

**Variante B — Manuell:**

1. `code` und `code_verifier` in den Body eintragen
2. Request absenden

### Schritt 6 — JWT dekodieren

Das Test-Script dekodiert Access Token und ID Token automatisch
und gibt sie in der **Postman Console** aus (View → Show Postman Console).

**Diskussionspunkte:**

- Welche Claims sind im ID Token vs. Access Token?
- Was bedeuten `sub`, `iss`, `aud`, `exp`?
- Warum gibt es ein `refresh_token`?

---

## Demo 2: Client Credentials Flow

### Schritt 1 — Token Request (Postman)

In Postman den Request **"Client Credentials Token"** öffnen und
absenden. Keine Browser-Interaktion nötig.

### Schritt 2 — JWT dekodieren

Das Test-Script zeigt den dekodierten Token in der Postman Console.

### Schritt 3 — Vergleich mit Demo 1

|                | Demo 1 (Auth Code) | Demo 2 (Client Cred.) |
|:---------------|:-------------------|:----------------------|
| access_token   | ja                 | ja                    |
| id_token       | ja                 | **nein**              |
| refresh_token  | ja                 | **nein**              |
| sub            | User-ID (demo)     | Service-Account-ID    |
| User-Claims    | name, email, ...   | keine                 |
| Browser nötig? | ja                 | **nein**              |

**Diskussionspunkte:**

- Warum kein ID Token? (Kein User wird authentifiziert)
- Warum kein Refresh Token? (Client kann jederzeit neue Tokens holen)
- Wann Client Credentials? (Service-to-Service, Batch-Jobs, Cronjobs)

---

## Aufräumen

```bash
docker compose down -v
```
