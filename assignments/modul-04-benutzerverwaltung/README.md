# Modul 04: Clients & Benutzerverwaltung

## Übungsziel

Am Ende dieser Übung hast du:

- Drei Mitarbeiter-Accounts angelegt
- Gruppen für Abteilungen erstellt
- Realm-Rollen für Berechtigungen definiert
- User zu Gruppen und Rollen zugewiesen
- Benutzerdefinierte Attribute konfiguriert

**Geschätzte Dauer:** 25-30 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet

### Umgebung starten

```bash
cd assignments/modul-04-benutzerverwaltung
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details siehe
> [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

Warte bis Keycloak bereit ist (~30 Sekunden). Der Realm "mustertech" wird automatisch importiert.

---

## Teil 1: Realm-Rollen erstellen

Rollen definieren, was Benutzer tun dürfen. Wir erstellen drei Rollen für unser Mitarbeiterportal.

### Schritt 1.1: Zu Realm roles navigieren

1. Öffne die Admin-Konsole: [http://localhost:8080](http://localhost:8080)
2. Wähle den Realm **mustertech**
3. Navigiere zu **Realm roles** (linke Navigation)

### Schritt 1.2: Rolle "mitarbeiter" erstellen

1. Klicke auf **Create role**
2. Gib ein:
   - **Role name:** `mitarbeiter`
   - **Description:** `Basis-Rolle für alle Mitarbeiter der Mustertech GmbH`
3. Klicke auf **Save**

### Schritt 1.3: Weitere Rollen erstellen

Erstelle analog zwei weitere Rollen:

| Role name | Description                                               |
|:----------|:----------------------------------------------------------|
| `manager` | Manager mit erweiterten Rechten (z.B. Urlaubsgenehmigung) |
| `admin`   | Administrator mit vollen Zugriffsrechten                  |

### Schritt 1.4: Rollen-Hierarchie einrichten (Composite Roles)

Manager sollten automatisch auch Mitarbeiter-Rechte haben. Wir machen `manager` zu einer **Composite Role**:

1. Klicke auf die Rolle **manager**
2. Wechsle zum Tab **Associated roles**
3. Drücke den Knopf **Assign role** -> **Realm roles**
5. Aktiviere **mitarbeiter**
6. Klicke auf **Assign**

Wiederhole dies für die Rolle **admin**:

- `admin` enthält `manager` (und damit auch `mitarbeiter`)

**Ergebnis:** Rollen-Hierarchie

```
admin
  └── manager
        └── mitarbeiter
```

---

## Teil 2: Gruppen erstellen

Gruppen repräsentieren die Organisationsstruktur. User können Gruppen zugewiesen werden und
erben deren Attribute und Rollen.

### Schritt 2.1: Zu Groups navigieren

1. Navigiere zu **Groups** (linke Navigation)
2. Die Liste ist noch leer

### Schritt 2.2: Hauptgruppen erstellen

Klicke auf **Create group** und erstelle:

| Group name | Beschreibung (intern) |
| :--- | :--- |
| `Entwicklung` | Softwareentwicklung |
| `Vertrieb` | Sales und Kundenbetreuung |
| `Management` | Führungskräfte |

### Schritt 2.3: Rollen zu Gruppen zuweisen

Jede Gruppe soll automatisch bestimmte Rollen erhalten:

**Gruppe "Entwicklung":**

1. Klicke auf **Entwicklung**
2. Wechsle zum Tab **Role mapping**
3. Klicke auf **Assign role** -> **Realm roles**
4. Wähle **mitarbeiter**
5. Klicke auf **Assign**

**Gruppe "Vertrieb":**

- Rolle: `mitarbeiter`

**Gruppe "Management":**

- Rolle: `manager`

### Schritt 2.4: Gruppen-Attribute hinzufügen

Gruppen können Attribute haben, die an Mitglieder vererbt werden:

1. Klicke auf **Entwicklung**
2. Wechsle zum Tab **Attributes**
3. Klicke auf **Add attribute**
4. Gib ein:
   - **Key:** `abteilung`
   - **Value:** `Entwicklung`
5. Klicke auf **Save**

Wiederhole für die anderen Gruppen:

| Gruppe | Key | Value |
| :--- | :--- | :--- |
| Vertrieb | `abteilung` | `Vertrieb` |
| Management | `abteilung` | `Management` |

---

## Teil 3: Benutzer anlegen

Jetzt erstellen wir drei Mitarbeiter mit unterschiedlichen Rollen.

### Schritt 3.1: Zu Users navigieren

1. Navigiere zu **Users** (linke Navigation)
2. Klicke auf **Create new user**

### Schritt 3.2: User "hans.mueller" erstellen

Gib folgende Daten ein:

| Feld | Wert |
| :--- | :--- |
| **Email verified** | ON |
| **Username** | `hans.mueller` |
| **Email** | `hans.mueller@mustertech.de` |
| **First name** | `Hans` |
| **Last name** | `Müller` |

Klicke auf **Create**.

### Schritt 3.3: Passwort setzen

Nach dem Erstellen wirst du zur User-Detailseite weitergeleitet:

1. Wechsle zum Tab **Credentials**
2. Klicke auf **Set password**
3. Gib ein:
   - **Password:** `test1234`
   - **Password confirmation:** `test1234`
   - **Temporary:** OFF (User muss Passwort nicht beim ersten Login ändern)
4. Klicke auf **Save**
5. Bestätige mit **Save password**

### Schritt 3.4: User zur Gruppe hinzufügen

1. Wechsle zum Tab **Groups**
2. Klicke auf **Join Group**
3. Wähle **Entwicklung**
4. Klicke auf **Join**

### Schritt 3.5: User-Attribute hinzufügen

1. Wechsle in die **Realm Settings**
2. Gehe weit rechts zum Tab **User Profile**
3. Klicke auf **Add attribute**
4. Vergib den Namen `personalnummer` und den Display Name `${personalnummer}`
5. Klicke auf **Save**
6. Wechsle wieder zu den Einstellungen des Benutzers `hans.mueller`
7. Füge unten hinzu:
   - **Key:** `personalnummer` | **Value:** `M-1001`
8. Klicke auf **Save**

### Schritt 3.6: Weitere User erstellen

Erstelle analog zwei weitere User:

**User: anna.schmidt**

| Feld | Wert |
| :--- | :--- |
| Username | `anna.schmidt` |
| Email | `anna.schmidt@mustertech.de` |
| First name | `Anna` |
| Last name | `Schmidt` |
| Attribut | `personalnummer` = `M-1002` |
| Gruppe | `Vertrieb` |
| Password | `test1234` (nicht temporär) |

**User: max.admin**

| Feld | Wert |
| :--- | :--- |
| Username | `max.admin` |
| Email | `max.admin@mustertech.de` |
| First name | `Max` |
| Last name | `Administrator` |
| Attribut | `personalnummer` = `M-0001` |
| Gruppe | `Management` |
| Password | `test1234` (nicht temporär) |

| **Zusätzliche Rolle** | `admin` (direkt zuweisen, siehe unten!) |

**Wichtig für max.admin:** Da die Management-Gruppe nur die `manager`-Rolle hat, müssen wir `admin` direkt zuweisen:

1. Öffne User **max.admin**
2. Wechsle zum Tab **Role mapping**
3. Klicke auf **Assign role**
4. Filtere nach **Realm roles**
5. Wähle **admin**
6. Klicke auf **Assign**

---

## Teil 4: Konfiguration verifizieren

### Aufgabe 4.1: Rollen-Vererbung prüfen

1. Öffne User **max.admin**
2. Gehe zu **Role mapping**
3. Prüfe die **Effective roles** (oben rechts "Hide inherited roles" deaktivieren)

**Erwartetes Ergebnis:**

- `admin` (direkt zugewiesen)
- `manager` (von admin geerbt)
- `mitarbeiter` (von manager geerbt)
- `default-roles-mustertech` (Standard)

### Aufgabe 4.2: Gruppen-Attribute prüfen

1. Öffne User **hans.mueller**
2. Gehe zu **Attributes**

**Frage:** Siehst du das Attribut `abteilung` vom User oder von der Gruppe?

> **Antwort:** Gruppen-Attribute werden nicht direkt beim User angezeigt, sondern erst zur
> Laufzeit aufgelöst (z.B. im Token).

### Aufgabe 4.3: Login testen

Teste den Login mit einem der neuen User:

1. Öffne die Account Console: <http://localhost:8080/realms/mustertech/account>
2. Klicke auf **Sign in**
3. Melde dich an als:
   - Username: `hans.mueller`
   - Password: `test1234`

**Erwartetes Ergebnis:** Du siehst die Account Console mit Hans Müllers Profil.

### Aufgabe 4.4: User-Liste prüfen

Zurück in der Admin-Konsole:

1. Navigiere zu **Users**
2. Klicke auf **View all users**

Du solltest drei User sehen.

---

## Teil 5: Erweiterte Aufgaben

### Aufgabe 5.1: Untergruppen erstellen (Optional)

Erstelle Untergruppen für die Entwicklungsabteilung:

1. Gehe zu **Groups** → **Entwicklung**
2. Klicke auf **Create group** (innerhalb von Entwicklung)
3. Erstelle:
   - `Backend`
   - `Frontend`

**Struktur:**

```
Entwicklung
├── Backend
└── Frontend
```

Verschiebe `hans.mueller` in die Untergruppe `Backend`.

### Aufgabe 5.2: Required Actions erkunden (Optional)

Required Actions sind Aktionen, die ein User beim nächsten Login ausführen muss.

1. Öffne User **anna.schmidt**
2. Wechsle zum Tab **Details**
3. Unter **Required user actions** wähle:
   - `Update Password`
4. Klicke auf **Save**

Teste den Login als `anna.schmidt` - was passiert?

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Drei Realm-Rollen erstellt (mitarbeiter, manager, admin)
- [x] Rollen-Hierarchie mit Composite Roles eingerichtet
- [x] Drei Gruppen für Abteilungen erstellt
- [x] Rollen und Attribute zu Gruppen zugewiesen
- [x] Drei Benutzer mit unterschiedlichen Rechten angelegt
- [x] Login mit einem User getestet

**Nächstes Modul:** Authentifizierung & MFA - Custom Flows und Conditional Authentication!

---

## Troubleshooting

### Container-Name-Konflikt

Siehe zentrales Troubleshooting: [Container-Name-Konflikt](../TROUBLESHOOTING.md#container-name-konflikt)

### User kann sich nicht einloggen

**Symptom:** "Invalid username or password"

**Prüfe:**

- Ist der User **Enabled**?
- Wurde das Passwort korrekt gesetzt?
- Ist **Temporary** beim Passwort auf OFF?

### Rolle wird nicht angezeigt

**Symptom:** User hat die erwartete Rolle nicht.

**Prüfe:**

- Ist die Rolle der Gruppe zugewiesen?
- Ist der User Mitglied der Gruppe?
- Bei Composite Roles: Ist die Hierarchie korrekt?

### Attribut fehlt im Token

**Hinweis:** Gruppen-Attribute erscheinen nicht automatisch im Token. Dafür benötigst du einen
**Protocol Mapper** (wird im Slide-Modul 04 behandelt).
