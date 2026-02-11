# Modul 09b: Anpassung – APIs & Erweiterungen

## Übungsziel

Am Ende dieser Übung hast du:

- Die Admin REST API verstanden und genutzt
- User per API angelegt und verwaltet
- Das Admin-CLI um API-Funktionen erweitert
- Token Introspection implementiert

**Geschätzte Dauer:** 35-45 Minuten

---

## Voraussetzungen

- [ ] Modul 09a abgeschlossen
- [ ] Admin-CLI aus Modul 06b vorhanden

---

## Teil 1: Admin REST API erkunden

### Schritt 1.1: API-Dokumentation

Die Admin REST API ist dokumentiert unter:

- **Swagger UI:** Nicht standardmäßig aktiviert
- **Offizielle Docs:** <https://www.keycloak.org/docs-api/latest/rest-api/>

### Schritt 1.2: API-Endpunkte verstehen

Basis-URL: `http://localhost:8080/admin/realms/{realm}`

| Endpunkt | Methode | Beschreibung |
| :--- | :--- | :--- |
| `/users` | GET | Alle User auflisten |
| `/users` | POST | User erstellen |
| `/users/{id}` | GET | User Details |
| `/users/{id}` | PUT | User aktualisieren |
| `/users/{id}` | DELETE | User löschen |
| `/users/{id}/reset-password` | PUT | Passwort setzen |
| `/groups` | GET | Alle Gruppen |
| `/roles` | GET | Alle Rollen |

### Schritt 1.3: Admin-Token beschaffen

Um die API zu nutzen, benötigst du einen Token mit Admin-Rechten:

```powershell
# Token holen (PowerShell)
$response = Invoke-RestMethod -Uri "http://localhost:8080/realms/master/protocol/openid-connect/token" `
  -Method Post `
  -Body @{
    grant_type = "password"
    client_id = "admin-cli"
    username = "admin"
    password = "admin"
  }

$token = $response.access_token
echo $token
```

Oder mit curl:

```bash
curl -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" | jq -r '.access_token'
```

---

## Teil 2: User per API verwalten

### Schritt 2.1: User auflisten

```bash
curl -X GET "http://localhost:8080/admin/realms/mustertech/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq
```

**Erwartete Antwort:**

```json
[
  {
    "id": "...",
    "username": "hans.mueller",
    "email": "hans.mueller@mustertech.de",
    "firstName": "Hans",
    "lastName": "Müller",
    "enabled": true
  },
  ...
]
```

### Schritt 2.2: User erstellen

```bash
curl -X POST "http://localhost:8080/admin/realms/mustertech/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "peter.neu",
    "email": "peter.neu@mustertech.de",
    "firstName": "Peter",
    "lastName": "Neu",
    "enabled": true,
    "emailVerified": true,
    "attributes": {
      "personalnummer": ["M-1003"]
    }
  }'
```

**Erfolg:** HTTP 201 Created (Location-Header enthält User-ID)

### Schritt 2.3: Passwort setzen

```bash
# User-ID ermitteln
USER_ID=$(curl -s "http://localhost:8080/admin/realms/mustertech/users?username=peter.neu" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Passwort setzen
curl -X PUT "http://localhost:8080/admin/realms/mustertech/users/$USER_ID/reset-password" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "password",
    "value": "Test1234!@",
    "temporary": false
  }'
```

### Schritt 2.4: User zu Gruppe hinzufügen

```bash
# Gruppen-ID ermitteln
GROUP_ID=$(curl -s "http://localhost:8080/admin/realms/mustertech/groups?search=Entwicklung" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# User zu Gruppe hinzufügen
curl -X PUT "http://localhost:8080/admin/realms/mustertech/users/$USER_ID/groups/$GROUP_ID" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Teil 3: Admin-CLI erweitern

### Schritt 3.1: API-Funktionen hinzufügen

Erweitere `services/admin-cli/src/index.ts`:

```typescript
// Nach erfolgreichem Login hinzufügen:

async function listUsers(token: string) {
  const response = await axios.get(
    `${KEYCLOAK_URL}/admin/realms/${REALM}/users`,
    { headers: { Authorization: `Bearer ${token}` } }
  );
  return response.data;
}

async function createUser(token: string, userData: any) {
  await axios.post(
    `${KEYCLOAK_URL}/admin/realms/${REALM}/users`,
    userData,
    { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } }
  );
}

// Im main() nach Login:
console.log('\n--- User-Verwaltung ---');
const action = readlineSync.question('Aktion (list/create/quit): ');

if (action === 'list') {
  const users = await listUsers(tokens.access_token);
  console.log('\nBenutzer:');
  users.forEach((u: any) => console.log(`- ${u.username} (${u.email})`));
}

if (action === 'create') {
  const username = readlineSync.question('Username: ');
  const email = readlineSync.question('E-Mail: ');
  const firstName = readlineSync.question('Vorname: ');
  const lastName = readlineSync.question('Nachname: ');

  await createUser(tokens.access_token, {
    username, email, firstName, lastName,
    enabled: true, emailVerified: true
  });
  console.log('User erstellt!');
}
```

---

## Teil 4: Token Introspection

### Schritt 4.1: Introspection Endpoint

Token Introspection prüft, ob ein Token gültig ist:

```bash
curl -X POST "http://localhost:8080/realms/mustertech/protocol/openid-connect/token/introspect" \
  -d "token=$ACCESS_TOKEN" \
  -d "client_id=portal-api" \
  -d "client_secret=$CLIENT_SECRET"
```

**Antwort (gültiger Token):**

```json
{
  "active": true,
  "sub": "user-id",
  "username": "hans.mueller",
  "exp": 1234567890,
  "realm_access": { "roles": ["mitarbeiter"] }
}
```

**Antwort (ungültiger Token):**

```json
{
  "active": false
}
```

### Schritt 4.2: In API integrieren (Optional)

Als Alternative zur lokalen JWT-Validierung kannst du Token Introspection verwenden - besonders nützlich für opaque Tokens.

---

## Teil 5: Weitere API-Endpunkte

### Schritt 5.1: Sessions verwalten

```bash
# Aktive Sessions eines Users
curl "http://localhost:8080/admin/realms/mustertech/users/$USER_ID/sessions" \
  -H "Authorization: Bearer $TOKEN"

# Alle Sessions eines Users beenden
curl -X DELETE "http://localhost:8080/admin/realms/mustertech/users/$USER_ID/sessions" \
  -H "Authorization: Bearer $TOKEN"
```

### Schritt 5.2: Events abfragen

```bash
# Letzte Login-Events
curl "http://localhost:8080/admin/realms/mustertech/events?type=LOGIN&max=10" \
  -H "Authorization: Bearer $TOKEN"
```

### Schritt 5.3: Realm-Konfiguration exportieren

```bash
curl "http://localhost:8080/admin/realms/mustertech" \
  -H "Authorization: Bearer $TOKEN" > realm-export.json
```

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Admin REST API Endpunkte verstanden
- [x] User per API aufgelistet und erstellt
- [x] Passwörter und Gruppenzugehörigkeit per API verwaltet
- [x] Admin-CLI um API-Funktionen erweitert
- [x] Token Introspection kennengelernt

**Wichtige API-Endpunkte:**

| Aufgabe | Endpunkt |
| :--- | :--- |
| User verwalten | `/admin/realms/{realm}/users` |
| Gruppen verwalten | `/admin/realms/{realm}/groups` |
| Rollen verwalten | `/admin/realms/{realm}/roles` |
| Sessions | `/admin/realms/{realm}/users/{id}/sessions` |
| Events | `/admin/realms/{realm}/events` |
| Token prüfen | `/realms/{realm}/.../token/introspect` |

**Nächstes Modul:** Betrieb, Sicherheit & Best Practices (Modul 10)!

---

## Troubleshooting

### 401 Unauthorized

- Token abgelaufen? Neuen Token holen.
- Token vom richtigen Realm? (master für Admin API)
- User hat Admin-Rechte?

### 403 Forbidden

- User hat nicht die nötigen Rollen
- Für Admin API: `realm-admin` oder spezifische Rollen nötig

### User kann nicht erstellt werden

- Username bereits vergeben?
- E-Mail bereits vergeben (wenn `duplicateEmailsAllowed=false`)?
- Pflichtfelder fehlen?
