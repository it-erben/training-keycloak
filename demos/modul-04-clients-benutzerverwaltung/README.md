# Live-Demo: Modul 04 -- Clients & Benutzerverwaltung

Das Rollenkonzept (Client Roles -> Composite Role -> Gruppe -> User) und Protocol Mapper
live aufbauen -- mit **anderen Clients und Usern** als in der Übung.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Client Roles anlegen | 2 Min |
| Demo 2 | Composite Role erstellen | 2 Min |
| Demo 3 | Gruppe + User anlegen | 2 Min |
| Demo 4 | Protocol Mapper konfigurieren | 2 Min |
| Demo 5 | Token evaluieren | 3 Min |
| Demo 6 | Service Account testen | 2 Min |

## Voraussetzungen

- Docker / Podman (Container-Runtime)

## Setup

```bash
# 1. Keycloak + Postgres starten (Port 9090)
docker compose up -d

# 2. Warten bis Keycloak bereit ist (~30 s)
docker compose logs -f demo-keycloak
# -> "Keycloak ... started in ..." abwarten, dann Ctrl+C
```

Keycloak Admin-Konsole: <http://localhost:9090> (admin / admin)

Der Realm **mustertech** wird automatisch importiert.

---

## Demo 1: Client Roles anlegen

Wir erstellen Client-spezifische Rollen für zwei fiktive Anwendungen.

### Schritt 1 -- Client "wiki-app" anlegen

1. Navigiere zu **Clients** -> **Create client**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Client type | OpenID Connect |
| Client ID | `wiki-app` |

3. Klicke auf **Next** -> **Next** -> **Save**

### Schritt 2 -- Client Role "editor" erstellen

1. Öffne **Clients** -> **wiki-app** -> Tab **Roles**
2. Klicke auf **Create role**
3. Gib ein:
   - **Role name:** `editor`
   - **Description:** `Darf Wiki-Seiten bearbeiten`
4. Klicke auf **Save**

### Schritt 3 -- Client "chat-app" mit Rolle "moderator"

1. Erstelle einen zweiten Client **chat-app** (gleiche Einstellungen wie oben)
2. Erstelle die Client Role **moderator** mit Description `Darf Chat-Nachrichten moderieren`

> **Zeigen:** Client Roles sind isoliert -- `wiki-app:editor` und `chat-app:moderator`
> existieren unabhängig voneinander. Keine Namenskonflikte möglich.

**Diskussionspunkte:**

- Warum Client Roles statt Realm Roles?
- Was passiert, wenn zwei Clients dieselbe Rolle "admin" brauchen?

---

## Demo 2: Composite Role erstellen

Wir bündeln die beiden technischen Rollen in einer Business-Rolle.

### Schritt 1 -- Realm Role "Team-Lead" erstellen

1. Navigiere zu **Realm roles** -> **Create role**
2. Gib ein:
   - **Role name:** `Team-Lead`
   - **Description:** `Bündelt wiki-app:editor und chat-app:moderator`
3. Klicke auf **Save**

### Schritt 2 -- Client Roles zuweisen

1. Wechsle zum Tab **Associated roles**
2. Klicke auf **Assign role** -> **Realm roles**
3. Aktiviere **wiki-app editor** und **chat-app moderator**
4. Klicke auf **Assign**

> **Zeigen:** Im Tab "Associated roles" sind jetzt beide Client Roles sichtbar. Ein User
> mit der Rolle "Team-Lead" bekommt automatisch beide technischen Rollen.

**Diskussionspunkte:**

- Wie skaliert das bei 20 Microservices?
- Wer pflegt die Zuordnung -- Keycloak-Admin oder App-Team?

---

## Demo 3: Gruppe und User anlegen

### Schritt 1 -- Attribut "department" im Realm anlegen

1. Navigiere zu **Realm settings** -> **User profile**
2. Klicke auf **Create attribute**
3. Gib den Namen `department` ein, Display Name `${department}`
4. Klicke auf **Save**

### Schritt 2 -- Gruppe "Engineering" erstellen

1. Navigiere zu **Groups** -> **Create group**
2. Name: `Engineering`
3. Klicke auf **Create**

### Schritt 3 -- Rolle zur Gruppe zuweisen

1. Öffne die Gruppe **Engineering**
2. Wechsle zum Tab **Role mapping**
3. Klicke auf **Assign role**
4. Filtere nach **Realm roles**
5. Wähle **Team-Lead**
6. Klicke auf **Assign**

### Schritt 4 -- User "alice" erstellen

1. Navigiere zu **Users** -> **Create new user**
2. Gib ein:

| Feld | Wert |
| :--- | :--- |
| Username | `alice` |
| Email | `alice@example.com` |
| Email verified | ON |
| First name | `Alice` |
| Last name | `Beispiel` |
| department | `Engineering` |

3. Klicke auf **Create**

### Schritt 5 -- Passwort setzen und Gruppe zuweisen

1. Tab **Credentials** -> **Set password** -> `demo1234`, Temporary: OFF
2. Tab **Groups** -> **Join Group** -> **Engineering** -> **Join**

> **Zeigen:** Alice bekommt Rollen nicht direkt -- sie erbt sie über die Gruppe. Das ist
> die goldene Regel: **User -> Group -> Composite Role -> Client Role**.

---

## Demo 4: Protocol Mapper konfigurieren

Wir machen das `department`-Attribut im Access Token sichtbar.

### Schritt 1 -- Dedicated Scope öffnen

1. Navigiere zu **Clients** -> **wiki-app**
2. Wechsle zum Tab **Client scopes**
3. Klicke auf **wiki-app-dedicated**

### Schritt 2 -- Mapper erstellen

1. Klicke auf **Configure a new mapper**
2. Wähle **User Attribute**
3. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `department-mapper` |
| User Attribute | `department` |
| Token Claim Name | `department` |
| Claim JSON Type | String |
| Add to ID token | ON |
| Add to access token | ON |
| Add to userinfo | ON |

4. Klicke auf **Save**

> **Zeigen:** Der Mapper liest das User-Attribut und schreibt es als Claim ins Token. Kein Code in der App nötig.

---

## Demo 5: Token evaluieren

Der Aha-Moment: Alice hat Client Roles, obwohl ihr nie direkt welche zugewiesen wurden.

### Schritt 1 -- Evaluate Tab öffnen

1. Navigiere zu **Clients** -> **wiki-app** -> Tab **Client scopes**
2. Klicke auf **Evaluate**
3. Wähle **User:** `alice`
4. Klicke auf **Generated access token**

### Schritt 2 -- Token analysieren

Prüfe folgende Claims:

| Claim | Erwarteter Wert |
| :--- | :--- |
| `resource_access.wiki-app.roles` | `["editor"]` |
| `department` | `Engineering` |
| `realm_access.roles` | enthält `Team-Lead` |

> **Zeigen:** Alice hat `wiki-app:editor` im Token, obwohl die Rolle nie direkt zugewiesen
> wurde. Die Kette: Alice -> Gruppe "Engineering" -> Realm Role "Team-Lead" -> Client Role
> "wiki-app:editor".

**Diskussionspunkte:**

- Wie kann eine App diesen Claim nutzen?
- Was passiert, wenn Alice die Gruppe wechselt?

---

## Demo 6: Service Account testen

Ein Client, der sich ohne User authentifiziert (Machine-to-Machine).

### Schritt 1 -- Confidential Client erstellen

1. Navigiere zu **Clients** -> **Create client**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Client type | OpenID Connect |
| Client ID | `batch-service` |

3. Klicke auf **Next**
4. Aktiviere:
   - **Client authentication:** ON
   - **Service accounts roles:** ON
5. Klicke auf **Next** -> **Save**

### Schritt 2 -- Client Secret kopieren

1. Wechsle zum Tab **Credentials**
2. Kopiere das **Client secret**

### Schritt 3 -- Token via curl abrufen

```bash
curl -X POST http://localhost:9090/realms/mustertech/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=batch-service" \
  -d "client_secret=<SECRET>"
```

> **Zeigen:** Kein Username/Passwort nötig -- der Client authentifiziert sich selbst. Im
> Token steht `sub = <Service-Account-UUID>`, kein menschlicher User.

**Diskussionspunkte:**

- Wann Client Credentials statt Authorization Code?
- Wie weist man dem Service Account Rollen zu?

---

## Aufräumen

```bash
docker compose down -v
```
