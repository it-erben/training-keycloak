# Modul 10a: Sicherheitsfunktionen & Hardening

## Übungsziel

Am Ende dieser Übung hast du:

- Eine Passwort-Policy für den Realm konfiguriert
- OTP (TOTP) für einen Admin-User eingerichtet
- Brute-Force-Protection aktiviert
- Session-Einstellungen angepasst
- Die Sicherheitsmaßnahmen getestet

**Geschätzte Dauer:** 25-30 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet
- Smartphone mit Authenticator-App (Google Authenticator, Microsoft
  Authenticator, Authy, etc.)

### Umgebung starten

```bash
cd assignments/modul-10a-sicherheit
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe
> diese zuerst mit `docker compose down -v` im Verzeichnis der vorherigen Übung.
> Details siehe [Troubleshooting](#container-name-konflikt).

Warte bis Keycloak bereit ist (~30 Sekunden). Der Realm "mustertech" wird
automatisch importiert mit allen Konfigurationen aus den vorherigen Modulen.

---

## Teil 1: Passwort-Policies konfigurieren

Passwort-Policies erzwingen sichere Passwörter bei der Registrierung und beim
Ändern.

### Schritt 1.1: Zu Password policies navigieren

1. Öffne die Admin-Konsole: <http://localhost:8080>
2. Wähle den Realm **mustertech**
3. Navigiere zu **Authentication** → **Policies** → **Password policy**

<!-- SCREENSHOT: keycloak-password-policy-empty.png -->
<!-- Beschreibung: Leere Password Policy Seite -->

### Schritt 1.2: Policies hinzufügen

Klicke auf **Add policy** und füge folgende Regeln hinzu:

| Policy                   | Wert | Beschreibung                          |
|:-------------------------|:-----|:--------------------------------------|
| **Minimum length**       | `10` | Mindestens 10 Zeichen                 |
| **Uppercase characters** | `1`  | Mindestens 1 Großbuchstabe            |
| **Lowercase characters** | `1`  | Mindestens 1 Kleinbuchstabe           |
| **Digits**               | `1`  | Mindestens 1 Ziffer                   |
| **Special characters**   | `1`  | Mindestens 1 Sonderzeichen            |
| **Not username**         | -    | Passwort darf nicht der Username sein |
| **Not email**            | -    | Passwort darf nicht die E-Mail sein   |

Klicke nach jeder Policy auf **Save**.

<!-- SCREENSHOT: keycloak-password-policy-configured.png -->
<!-- Beschreibung: Konfigurierte Password Policies -->

### Schritt 1.3: Password Policy testen

1. Navigiere zu **Users** → **hans.mueller**
2. Gehe zu **Credentials** → **Reset password**
3. Versuche, ein schwaches Passwort zu setzen: `test`
4. Klicke auf **Save**

**Erwartetes Ergebnis:** Fehlermeldung, dass das Passwort die Policy nicht
erfüllt.

Setze nun ein gültiges Passwort: `Test1234!@`

---

## Teil 2: OTP/MFA einrichten

One-Time Passwords (OTP) bieten einen zweiten Faktor für die Authentifizierung.

### Schritt 2.1: OTP-Policy prüfen

1. Navigiere zu **Authentication** → **Policies** → **OTP policy**
2. Prüfe die Standardeinstellungen:

| Einstellung           | Empfohlener Wert  |
|:----------------------|:------------------|
| **OTP type**          | Time-based (TOTP) |
| **Algorithm**         | SHA1              |
| **Number of digits**  | 6                 |
| **Look ahead window** | 1                 |
| **OTP token period**  | 30 (Sekunden)     |

Diese Standardwerte sind für die meisten Authenticator-Apps kompatibel.

<!-- SCREENSHOT: keycloak-otp-policy.png -->
<!-- Beschreibung: OTP Policy Einstellungen -->

### Schritt 2.2: OTP für max.admin einrichten

Wir konfigurieren OTP als Required Action für den Admin-User:

1. Navigiere zu **Users** → **max.admin**
2. Gehe zum Tab **Details**
3. Unter **Required user actions** wähle **Configure OTP**
4. Klicke auf **Save**

<!-- SCREENSHOT: keycloak-user-required-action.png -->
<!-- Beschreibung: Required Action "Configure OTP" beim User -->

### Schritt 2.3: OTP als User einrichten

Jetzt simulieren wir den User-Flow:

1. Öffne ein **Inkognito-Fenster** im Browser
2. Gehe zu: <http://localhost:8080/realms/mustertech/account>
3. Klicke auf **Sign in**
4. Melde dich an:
    - Username: `max.admin`
    - Password: `test1234`

5. Du wirst zur OTP-Einrichtung weitergeleitet:

<!-- SCREENSHOT: keycloak-otp-setup.png -->
<!-- Beschreibung: QR-Code für OTP-Einrichtung -->

6. Scanne den QR-Code mit deiner Authenticator-App
7. Gib den 6-stelligen Code aus der App ein
8. Klicke auf **Submit**

**Erwartetes Ergebnis:** Du bist eingeloggt und OTP ist aktiviert.

### Schritt 2.4: OTP-Login testen

1. Melde dich ab (Sign out)
2. Melde dich erneut als `max.admin` an
3. Nach Username/Passwort wirst du nach dem OTP-Code gefragt

<!-- SCREENSHOT: keycloak-otp-login.png -->
<!-- Beschreibung: OTP-Eingabe beim Login -->

---

## Teil 3: Brute-Force-Protection

Brute-Force-Protection verhindert automatisierte Angriffe auf Benutzerkonten.

### Schritt 3.1: Brute-Force-Protection aktivieren

1. Navigiere zu **Realm settings** → **Security defenses**
2. Wechsle zum Tab **Brute force detection**
3. Aktiviere **Enabled**

### Schritt 3.2: Parameter konfigurieren

| Parameter                    | Wert             | Beschreibung                          |
|:-----------------------------|:-----------------|:--------------------------------------|
| **Permanent lockout**        | OFF              | Account wird nicht permanent gesperrt |
| **Max login failures**       | `5`              | Nach 5 Fehlversuchen wird gesperrt    |
| **Wait increment**           | `60` Sekunden    | Sperrzeit nach Fehlversuchen          |
| **Quick login check**        | `1000` ms        | Mindestzeit zwischen Login-Versuchen  |
| **Minimum quick login wait** | `60` Sekunden    | Sperrzeit bei zu schnellen Versuchen  |
| **Max wait**                 | `900` Sekunden   | Maximale Sperrzeit (15 Min)           |
| **Failure reset time**       | `43200` Sekunden | Fehlerzähler Reset nach 12h           |

Klicke auf **Save**.

<!-- SCREENSHOT: keycloak-brute-force.png -->
<!-- Beschreibung: Brute Force Detection Einstellungen -->

### Schritt 3.3: Brute-Force-Protection testen

1. Öffne ein Inkognito-Fenster
2. Versuche, dich als `hans.mueller` mit falschem Passwort anzumelden
3. Wiederhole dies 5+ Mal

**Erwartetes Ergebnis:** Nach 5 Fehlversuchen erscheint eine Meldung, dass der
Account temporär gesperrt ist.

### Schritt 3.4: Gesperrten Account prüfen

In der Admin-Konsole:

1. Navigiere zu **Users** → **hans.mueller**
2. Gehe zum Tab **Sessions**
3. Unter **Brute force detection** siehst du den Status

Um den Account zu entsperren:

- Klicke auf **Clear login failures** (falls sichtbar)
- Oder warte die Sperrzeit ab

---

## Teil 4: Session-Management

Sessions kontrollieren, wie lange Benutzer eingeloggt bleiben.

### Schritt 4.1: Session-Einstellungen öffnen

1. Navigiere zu **Realm settings** → **Sessions**

### Schritt 4.2: Timeouts konfigurieren

| Einstellung              | Empfehlung | Beschreibung                     |
|:-------------------------|:-----------|:---------------------------------|
| **SSO Session Idle**     | 30 Minuten | Logout nach 30 Min Inaktivität   |
| **SSO Session Max**      | 10 Stunden | Max. Dauer einer Session         |
| **Client Session Idle**  | 30 Minuten | Client-spezifischer Idle-Timeout |
| **Client Session Max**   | 10 Stunden | Max. Client-Session-Dauer        |
| **Offline Session Idle** | 30 Tage    | Für Refresh Tokens               |
| **Offline Session Max**  | 60 Tage    | Max. Offline-Session             |

Für die Entwicklung kannst du kürzere Werte verwenden, um das Verhalten zu
testen:

| Einstellung          | Test-Wert  |
|:---------------------|:-----------|
| **SSO Session Idle** | 5 Minuten  |
| **SSO Session Max**  | 30 Minuten |

Klicke auf **Save**.

### Schritt 4.3: Aktive Sessions verwalten

1. Navigiere zu **Sessions** (linke Navigation)
2. Du siehst alle aktiven Sessions im Realm
3. Du kannst einzelne Sessions oder alle Sessions beenden

<!-- SCREENSHOT: keycloak-sessions.png -->
<!-- Beschreibung: Liste aktiver Sessions -->

**Admin-Tipp:** Bei einem Sicherheitsvorfall kannst du hier alle Sessions
beenden, um alle User auszuloggen.

---

## Teil 5: Weitere Sicherheitseinstellungen

### Aufgabe 5.1: Headers konfigurieren

1. Navigiere zu **Realm settings** → **Security defenses** → **Headers**
2. Prüfe die Standard-Security-Header:

| Header                  | Zweck                         |
|:------------------------|:------------------------------|
| X-Frame-Options         | Schutz vor Clickjacking       |
| Content-Security-Policy | Schutz vor XSS                |
| X-Content-Type-Options  | Verhindert MIME-Type-Sniffing |
| X-XSS-Protection        | Browser-XSS-Filter            |

Diese Standardwerte sind für die meisten Fälle geeignet.

### Aufgabe 5.2: Events aktivieren (für Audit)

1. Navigiere zu **Realm settings** → **Events**
2. Tab **User events settings**:
    - **Save events:** ON
    - **Expiration:** 7 Tage (oder länger für Compliance)
    - **Saved types:** Alle relevanten Events aktivieren
3. Tab **Admin events settings**:
    - **Save events:** ON
    - **Include representation:** ON (für vollständiges Audit-Log)
4. Klicke auf **Save**

<!-- SCREENSHOT: keycloak-events-config.png -->
<!-- Beschreibung: Event-Konfiguration -->

### Aufgabe 5.3: Events ansehen

1. Navigiere zu **Events** → **User events**
2. Hier siehst du Login-Versuche, Fehler, etc.

Filtere nach:

- **Event type:** `LOGIN_ERROR`
- **User:** `hans.mueller`

Du solltest die fehlgeschlagenen Login-Versuche aus dem Brute-Force-Test sehen.

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Passwort-Policy mit Komplexitätsanforderungen konfiguriert
- [x] OTP/MFA für den Admin-User eingerichtet
- [x] Brute-Force-Protection aktiviert und getestet
- [x] Session-Timeouts angepasst
- [x] Security-Events aktiviert

**Sicherheitsstatus:**

| Feature              | Status                                           |
|:---------------------|:-------------------------------------------------|
| Passwort-Komplexität | Aktiviert (min. 10 Zeichen, Sonderzeichen, etc.) |
| MFA                  | Aktiviert für max.admin                          |
| Brute-Force-Schutz   | Aktiviert (5 Versuche, dann Sperre)              |
| Session-Timeout      | 30 Min Idle, 10h Max                             |
| Audit-Logging        | Aktiviert                                        |

**Weiter:** Modul 10b - Best Practices & Produktion!

---

## Troubleshooting

### Container-Name-Konflikt

**Symptom:** Beim Start erscheint ein Fehler wie:

```
Error response from daemon: Conflict. The container name "/assignment-postgres" is already
in use by container "...". You have to remove (or rename) that container to be able to
reuse that name.
```

**Ursache:** Die Container einer vorherigen Übung laufen noch oder wurden nicht
vollständig entfernt.

**Lösung:** Wechsle in das Verzeichnis der vorherigen Übung und räume dort auf:

```bash
cd assignments/<vorherige-uebung>
docker compose down -v
```

Danach kannst du die aktuelle Übung normal starten.

### OTP-Code wird nicht akzeptiert

**Mögliche Ursachen:**

- Uhrzeit auf Server und Smartphone nicht synchron (TOTP ist zeitbasiert!)
- Falscher QR-Code gescannt (alter Code)

**Lösung:**

- Smartphone-Zeit prüfen (automatische Zeit empfohlen)
- OTP-Credential für User löschen und neu einrichten

### Account ist gesperrt

**Symptom:** "Account is temporarily disabled"

**Lösung (Admin-Konsole):**

1. Users → [Username]
2. Sessions Tab
3. "Clear login failures" klicken

### Passwort-Policy wird nicht angewendet

**Prüfen:**

- Policy wurde gespeichert?
- Policy gilt nur für neue/geänderte Passwörter, nicht für bestehende!

---

## Bonus: Passwort-Rotation erzwingen

Falls du möchtest, dass alle User ihr Passwort ändern müssen:

1. Navigiere zu **Authentication** → **Required actions**
2. Finde **Update Password**
3. Aktiviere **Set as default action**

Alle neuen User müssen dann beim ersten Login ihr Passwort ändern.

Für bestehende User:

1. Users → [User auswählen]
2. Required user actions → **Update Password**
3. Save
