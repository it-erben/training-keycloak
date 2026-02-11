# Modul 07: Identity Provider & Federation

## Übungsziel

Am Ende dieser Übung hast du:

- GitHub als externen Identity Provider konfiguriert
- Den First Login Flow verstanden
- Attribute-Mapping zwischen GitHub und Keycloak eingerichtet
- Social Login im Portal getestet

**Geschätzte Dauer:** 20-25 Minuten

---

## Voraussetzungen

- [ ] Modul 06 abgeschlossen (Portal läuft)
- [ ] GitHub-Account vorhanden
- [ ] GitHub OAuth App Credentials vom Trainer erhalten

---

## Teil 1: GitHub als Identity Provider hinzufügen

### Schritt 1.1: Identity Providers öffnen

1. Öffne die Admin-Konsole: <http://localhost:8080>
2. Wähle den Realm **mustertech**
3. Navigiere zu **Identity providers**

### Schritt 1.2: GitHub auswählen

Wähle **GitHub** aus der Liste der Social Providers

Gib die vom Trainer erhaltenen Credentials ein:

| Feld | Wert |
| :--- | :--- |
| **Alias** | `github` |
| **Display name** | `GitHub` |
| **Client ID** | (vom Trainer) |
| **Client Secret** | (vom Trainer) |

Klicke auf **Add**. Aktiviere in den **Advanced Settings**
folgende Merkmale:

| Feld | Wert |
| :--- | :--- |
| **Store tokens** | `On` |
| **Trust Email** | `On` |

### Schritt 1.4: Redirect URI notieren

Nach dem Speichern siehst du die **Redirect URI**:

```
http://localhost:8080/realms/mustertech/broker/github/endpoint
```

Diese URL ist bereits in der GitHub OAuth App konfiguriert (vom Trainer vorbereitet).

---

## Teil 2: First Login Flow verstehen

Wenn ein User sich zum ersten Mal über GitHub anmeldet, durchläuft er den **First Broker Login Flow**.

### Schritt 2.1: First Login Flow erkunden

1. Navigiere zu **Authentication**
2. Finde **first broker login**
3. Analysiere die Schritte (Diagramm vereinfacht):

```
first broker login
├── Review Profile (REQUIRED)              → User prüft/ergänzt Profil
└── User Creation Or Linking (REQUIRED)    → User wird erstellt oder verlinkt
    ├── Create User If Unique (ALTERNATIVE)    → User wird erstellt wenn E-Mail/Username eindeutig
    └── Handle Existing Account (ALTERNATIVE)
        ├── Confirm Link Existing Account      → Bei E-Mail-Konflikt: Account verknüpfen?
        └── Verify Existing Account by Email   → Verifikation per E-Mail
```

### Schritt 2.2: Flow-Verhalten verstehen

| Szenario | Verhalten |
| :--- | :--- |
| **Neue E-Mail** | User wird automatisch erstellt |
| **E-Mail existiert bereits** | User wird gefragt, ob Accounts verknüpft werden sollen |
| **Username-Konflikt** | User muss Username ändern |

---

## Teil 3: Attribute Mapping konfigurieren

GitHub liefert verschiedene Attribute, die wir in Keycloak übernehmen können.

### Schritt 3.1: Mappers öffnen

1. Navigiere zu **Identity providers** → **github**
2. Wechsle zum Tab **Mappers**

### Schritt 3.2: Mapper für GitHub-Username hinzufügen

GitHub liefert den Login-Namen, den wir als Attribut speichern können:

1. Klicke auf **Add mapper**
2. Wähle **Attribute Importer**
3. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| **Name** | `github-username` |
| **Sync mode override** | `inherit` |
| **Mapper type** | `Attribute importer` |
| **Social profile JSON field path** | `login` |
| **User attribute name** | `Custom Attribute -> github_username` |

Klicke auf **Save**.

### Schritt 3.3: Mapper für Avatar-URL hinzufügen (Optional)

1. Klicke auf **Add mapper**
2. Wähle **Attribute Importer**
3. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| **Name** | `github-avatar` |
| **Sync mode override** | `inherit` |
| **Mapper type** | `Attribute importer` |
| **Social profile JSON field path** | `avatar_url` |
| **User attribute name** | `Custom Attribute ->  picture` |

### Schritt 3.4: Attribute im User Profile sichtbar machen

Damit die neuen Attribute in der Admin-Konsole angezeigt werden, müssen sie im User Profile definiert werden:

1. Navigiere zu **Realm settings** → **User profile**
2. Klicke auf **Create attribute**
3. Lege das Attribut `github_username` an:

| Feld | Wert |
| :--- | :--- |
| **Name** | `github_username` |
| **Display name** | `GitHub Username` |

4. Unter **Permissions** setze:

| Feld | Wert |
| :--- | :--- |
| **Who can edit** | `Admin` |
| **Who can view** | `Admin` |

5. Klicke auf **Create**
6. Wiederhole die Schritte für `picture`:

| Feld | Wert |
| :--- | :--- |
| **Name** | `picture` |
| **Display name** | `Avatar URL` |
| **Who can edit** | `Admin` |
| **Who can view** | `Admin` |

7. Klicke auf **Save**

Die Attribute erscheinen nun im User-Detail neben den bereits vorhandenen Feldern wie `personalnummer`.

---

## Teil 4: Social Login testen

### Schritt 4.1: Portal öffnen

1. Öffne <http://localhost:5173>
2. Falls eingeloggt, melde dich ab

### Schritt 4.2: GitHub-Login starten

1. Klicke auf **Anmelden mit Keycloak**
2. Auf der Keycloak-Login-Seite siehst du jetzt **GitHub** als Option
3. Klicke auf **GitHub**

### Schritt 4.3: Bei GitHub autorisieren

1. Du wirst zu GitHub weitergeleitet
2. Melde dich bei GitHub an (falls nicht bereits eingeloggt)
3. Autorisiere die OAuth App

---

## Teil 5: Verknüpften User prüfen

### Schritt 5.1: User in Admin-Konsole finden

1. Öffne die Admin-Konsole
2. Navigiere zu **Users**
3. Suche nach deinem GitHub-Username oder E-Mail

### Schritt 5.2: Identity Provider Links prüfen

1. Öffne den User
2. Wechsle zum Tab **Identity provider links**
3. Du siehst die Verknüpfung zu GitHub

### Schritt 5.3: Attribute prüfen

1. Wechsle zum Tab **Attributes**
2. Du solltest sehen:
   - `github_username` (falls Mapper konfiguriert)
   - `picture` (Avatar-URL, falls Mapper konfiguriert)

---

## Teil 6: Erweiterte Konfiguration

### Aufgabe 6.1: Default Identity Provider (Optional)

Wenn du möchtest, dass User direkt zu GitHub weitergeleitet werden:

1. Navigiere zu **Authentication** → **browser** Flow
2. Finde **Identity Provider Redirector**
3. Klicke auf das Zahnrad
4. Setze **Default Identity Provider** auf `github`

**Hinweis:** Dies überspringt die Keycloak-Login-Seite komplett!

### Aufgabe 6.2: Account Linking für bestehende User

Bestehende User können ihren Account mit GitHub verknüpfen:

1. Login als bestehender User (z.B. hans.mueller)
2. Öffne die Account Console: <http://localhost:8080/realms/mustertech/account>
3. Navigiere zu **Linked accounts**
4. Klicke bei GitHub auf **Link account**

### Aufgabe 6.3: Gruppen/Rollen für Social Login User

Social Login User haben standardmäßig keine speziellen Rollen. Um ihnen automatisch Rollen zuzuweisen:

1. Navigiere zu **Identity providers** → **github**
2. Wechsle zum Tab **Mappers**
3. Klicke auf **Add mapper**
4. Wähle **Hardcoded Role**
5. Konfiguriere:
   - **Name:** `default-role-github`
   - **Role:** `mitarbeiter`

Jetzt erhalten alle GitHub-User automatisch die Rolle `mitarbeiter`.

---

## Zusammenfassung

Du hast erfolgreich:

- [x] GitHub als Identity Provider konfiguriert
- [x] Den First Login Flow verstanden
- [x] Attribute Mapping eingerichtet
- [x] Social Login im Portal getestet
- [x] Verknüpfte Accounts geprüft

**Nächstes Modul:** Zugriffskontrolle & Authorization Services (Modul 08)!

---

## Troubleshooting

### "Invalid redirect_uri" bei GitHub

**Ursache:** Die Redirect URI in der GitHub OAuth App stimmt nicht.

**Lösung:** Der Trainer muss die OAuth App prüfen:

```
Redirect URI: http://localhost:8080/realms/mustertech/broker/github/endpoint
```

### E-Mail-Konflikt beim ersten Login

**Symptom:** "User with email already exists"

**Lösung:**

- Option A: Bestehenden Account mit GitHub verknüpfen (Link anklicken)
- Option B: Andere E-Mail bei GitHub verwenden

### GitHub-Button erscheint nicht

**Prüfen:**

- Ist der Identity Provider **Enabled**?
- Ist der richtige Realm ausgewählt?
- Browser-Cache leeren

### Attribute werden nicht übernommen

**Prüfen:**

- Mapper korrekt konfiguriert?
- JSON Field Path korrekt? (z.B. `login`, nicht `username`)
- Sync Mode: `inherit` oder `force`?
