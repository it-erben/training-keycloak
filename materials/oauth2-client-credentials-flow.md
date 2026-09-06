# OAuth 2.0: Client Credentials Flow

## Deine Aufgabe

Stelle den anderen Teilnehmenden den **Client Credentials Flow** vor (~10
Minuten). Nutze dieses Material als Grundlage. Du kannst es ergänzen oder
anpassen.

---

## 1. Was ist der Client Credentials Flow?

Der Client Credentials Flow ist ein OAuth 2.0 Grant Type für die
**Machine-to-Machine-Kommunikation (M2M)**. Es gibt keinen Benutzer, der sich
einloggt, stattdessen authentifiziert sich eine **Anwendung direkt** beim
Authorization Server.

**Kernidee:** Die Anwendung selbst ist der "Benutzer".

### Wann wird er eingesetzt?

- Backend-Services, die untereinander kommunizieren (Microservices)
- Cronjobs oder Batch-Prozesse, die auf geschützte APIs zugreifen
- CLI-Tools oder Daemons ohne Benutzerinteraktion
- IoT-Backends, die Daten an eine zentrale API senden

### Wann ist er NICHT geeignet?

- Wenn ein **Benutzer** sich anmelden muss (dafür: Authorization Code Flow)
- Wenn die Anwendung im **Browser** läuft (Client Secret kann nicht sicher
  gespeichert werden)
- Wenn **benutzerspezifische** Berechtigungen nötig sind

---

## 2. Ablauf des Flows

Der Client Credentials Flow ist der **einfachste** aller OAuth 2.0 Flows, er
besteht aus nur einem einzigen Request-Response-Paar:

```
┌──────────┐                           ┌──────────────────────┐
│          │  1. Token Request         │                      │
│  Client  │  (client_id + secret)     │  Authorization       │
│  (App)   │ ─────────────────────────>│  Server (Keycloak)   │
│          │                           │                      │
│          │  2. Access Token          │                      │
│          │ <─────────────────────────│                      │
└──────────┘                           └──────────────────────┘
      │
      │  3. API-Aufruf mit Access Token
      v
┌──────────────────┐
│  Resource Server │
│  (geschützte API)│
└──────────────────┘
```

### Schritt für Schritt

1. **Token Request:** Der Client sendet seine `client_id` und sein
   `client_secret` direkt an den Token-Endpoint.
2. **Token Response:** Der Authorization Server prüft die Credentials und gibt
   ein Access Token zurück.
3. **API-Aufruf:** Der Client nutzt das Access Token, um auf die geschützte API
   zuzugreifen.

> **Beachte:** Es gibt keinen Browser-Redirect, keinen Login-Dialog und keinen
> Benutzer-Consent. Der gesamte Flow findet Backend-seitig statt.

---

## 3. Beispiel-HTTP-Requests

### Token Request

```http
POST /realms/mustertech/protocol/openid-connect/token HTTP/1.1
Host: keycloak.example.com
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=reporting-service
&client_secret=mein-geheimes-passwort
&scope=api:read
```

### Token Response

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 300,
  "scope": "api:read"
}
```

> **Wichtig:** Es gibt kein `refresh_token` und kein `id_token`,
> beides ergibt ohne Benutzer keinen Sinn.

### API-Aufruf mit dem Token

```http
GET /api/reports HTTP/1.1
Host: api.example.com
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## 4. Vergleich mit dem Authorization Code Flow

| Aspekt                  | Authorization Code Flow | Client Credentials Flow |
|:------------------------|:------------------------|:------------------------|
| **Benutzer beteiligt?** | Ja                      | Nein                    |
| **Browser nötig?**      | Ja (Redirect)           | Nein                    |
| **Anzahl Requests**     | Mehrere (Auth + Token)  | Einer (nur Token)       |
| **Erhaltene Tokens**    | Access + Refresh + ID   | Nur Access Token        |
| **Typischer Client**    | Web-App, Mobile App     | Backend-Service, Daemon |

---

## 5. Sicherheitsaspekte

- Das **Client Secret muss geheim bleiben**, es darf niemals im Frontend oder
  in öffentlich zugänglichem Code stehen.
- Access Tokens sollten eine **kurze Lebensdauer** haben (z.B. 5 Minuten).
- Berechtigungen werden über **Scopes** und/oder **Client Roles** in Keycloak
  gesteuert.
- Für noch mehr Sicherheit: **Mutual TLS (mTLS)** statt Client Secret verwenden.

---

## 6. Diskussionsfragen für die Gruppe

- In welchen Szenarien in eurem Arbeitsalltag würdet ihr den Client Credentials
  Flow einsetzen?
- Warum gibt es beim Client Credentials Flow kein Refresh Token?
- Was passiert, wenn das Client Secret kompromittiert wird, und wie kann man
  sich davor schützen?

---

## Hinweise zu den Diskussionsfragen

### "In welchen Szenarien würdet ihr den Client Credentials Flow einsetzen?"

Typische Antworten aus der Praxis:

- Ein **Monitoring-Service** fragt regelmäßig eine interne API ab, um
  Health-Daten zu sammeln.
- Ein **Nightly-Batch-Job** synchronisiert Daten zwischen zwei Systemen
  (z.B. HR-System und Keycloak).
- Ein **Microservice A** ruft Microservice B auf, um eine Bestellung
  weiterzuverarbeiten, ohne dass ein Benutzer direkt beteiligt ist.
- Ein **CI/CD-Pipeline-Schritt** deployt oder konfiguriert Ressourcen
  über eine geschützte API.

### "Warum gibt es kein Refresh Token?"

- Der Client hat seine Credentials (client_id + secret) **jederzeit
  verfügbar**, er kann sich also jederzeit ein neues Access Token holen.
- Ein Refresh Token würde **keinen Mehrwert** bieten, weil der
  Token-Request genauso einfach ist wie ein Refresh.
- Beim Authorization Code Flow ist das anders: Dort wurde der Benutzer
  einmal interaktiv authentifiziert, und das Refresh Token erspart ihm
  ein erneutes Login. Beim Client Credentials Flow gibt es keine
  Benutzerinteraktion, die man "einsparen" müsste.

### "Was passiert bei kompromittiertem Client Secret?"

- Ein Angreifer kann sich **als der Client ausgeben** und dessen
  Berechtigungen (Scopes/Roles) nutzen, er erhält vollen Zugriff
  auf alles, was dem Client erlaubt ist.
- **Sofortmaßnahme:** Secret rotieren (in Keycloak ein neues Secret
  generieren), alle bestehenden Tokens des Clients invalidieren.
- **Schutzmaßnahmen:**
  - Secrets niemals in Code oder Versionskontrolle speichern, sondern
    in einem **Secret Manager** (z.B. Vault, AWS Secrets Manager).
  - **Mutual TLS (mTLS)** statt Client Secret verwenden, ein
    Zertifikat ist schwerer zu kompromittieren.
  - **Least Privilege:** Dem Client nur die minimal nötigen Scopes/Roles
    zuweisen, um den Schaden bei Kompromittierung zu begrenzen.
  - Regelmäßige **Secret-Rotation** einrichten.
