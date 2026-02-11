# Live-Demo: Modul 10 — Betrieb & Sicherheit

Brute-Force-Detection, Password Policy und Events live konfigurieren und testen — mit einem dedizierten Demo-User, Fokus auf den Audit-Trail.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Brute-Force-Detection aktivieren | 2 Min |
| Demo 2 | Password Policy einrichten | 2 Min |
| Demo 3 | Events aktivieren | 2 Min |
| Demo 4 | Brute-Force testen | 3 Min |
| Demo 5 | Events prüfen (Audit-Trail) | 3 Min |

## Voraussetzungen

- Keycloak läuft (Realm **mustertech** existiert)
- Admin-Konsole erreichbar unter <http://localhost:8080>
- Ein Demo-User vorhanden (z.B. `alice` oder ein neuer User `demo-user`)

---

## Demo 1: Brute-Force-Detection aktivieren

### Schritt 1 — Security Defenses öffnen

1. Navigiere zu **Realm settings** → **Security defenses**
2. Wechsle zum Tab **Brute force detection**

### Schritt 2 — Konfigurieren

| Einstellung | Wert |
| :--- | :--- |
| Enabled | **Lockout temporarily** |
| Max login failures | `3` |
| Wait increment | `60` Sekunden |
| Quick login check | `1000` Millisekunden |
| Max wait | `900` Sekunden |

Klicke auf **Save**.

> **Zeigen:** Bewusst niedriger Wert (3 statt 5), damit die Demo schnell geht. In Produktion empfehlen sich 5-10 Versuche.

---

## Demo 2: Password Policy einrichten

### Schritt 1 — Policies hinzufügen

1. Navigiere zu **Authentication** → **Policies** → **Password policy**
2. Füge nacheinander hinzu:

| Policy | Wert |
| :--- | :--- |
| Minimum length | `12` |
| Not username | - |
| Password history | `3` |

Klicke nach jeder Policy auf **Save**.

> **Zeigen:** Policies greifen nur bei **Passwort-Änderungen**, nicht rückwirkend. Bestehende schwache Passwörter bleiben gültig, bis der User sie ändert.

**Diskussionspunkte:**

- Warum nicht rückwirkend? (Keycloak speichert nur Hashes, nicht das Klartext-Passwort)
- Was passiert bei Admin-Reset? (Policy wird auch geprüft)

---

## Demo 3: Events aktivieren

### Schritt 1 — User Events konfigurieren

1. Navigiere zu **Realm settings** → **Events** → **User events settings**
2. Aktiviere **Save events:** ON
3. Setze **Expiration:** `30` Tage
4. Klicke auf **Save**

### Schritt 2 — Admin Events konfigurieren

1. Wechsle zum Tab **Admin events settings**
2. Aktiviere **Save events:** ON
3. Aktiviere **Include representation:** ON
4. Klicke auf **Save**

> **Zeigen:** "Include representation" speichert den Vorher/Nachher-Zustand bei Admin-Änderungen. Damit kann man nachvollziehen, WAS genau geändert wurde — nicht nur DASS etwas geändert wurde.

---

## Demo 4: Brute-Force testen

### Schritt 1 — Account Console öffnen

1. Öffne ein **Inkognito-Fenster**
2. Navigiere zu: <http://localhost:8080/realms/mustertech/account>

### Schritt 2 — Fehlgeschlagene Logins provozieren

1. Gib den Username eines bestehenden Users ein (z.B. `alice`)
2. Gib ein **falsches Passwort** ein
3. Wiederhole dies **4 Mal**

### Schritt 3 — Sperre beobachten

Nach dem 3. Fehlversuch zeigt Keycloak: **"Account is temporarily disabled"**

> **Zeigen:** Der 4. Versuch wird sofort abgelehnt — auch mit dem richtigen Passwort. Das schützt gegen automatisierte Angriffe.

### Schritt 4 — Account entsperren

1. Wechsle zur Admin-Konsole
2. Navigiere zu **Users** → Betroffenen User öffnen
3. Wechsle zum Tab **Sessions**
4. Klicke auf **Clear login failures**

> **Zeigen:** Der Admin muss aktiv eingreifen (oder die Sperrzeit abwarten). In Produktion sollte es einen Prozess dafür geben.

### Schritt 5 — Login mit korrektem Passwort

1. Wechsle zurück zum Inkognito-Fenster
2. Melde dich mit dem **korrekten Passwort** an
3. Login ist wieder erfolgreich

---

## Demo 5: Events prüfen (Audit-Trail)

### Schritt 1 — User Events filtern

1. Navigiere zu **Realm settings** → **Events** → Tab **User events**
2. Filtere:
   - **Event type:** `LOGIN_ERROR`
3. Klicke auf **Search**

> **Zeigen:** Jeder fehlgeschlagene Login wird protokolliert — mit Timestamp, IP-Adresse, Username und Error-Details. Das ist der Audit-Trail für Sicherheitsvorfälle.

### Schritt 2 — Event-Details analysieren

Klicke auf ein Event und zeige:

| Feld | Bedeutung |
| :--- | :--- |
| Time | Wann ist es passiert? |
| Type | LOGIN_ERROR |
| IP Address | Von welcher IP? |
| Error | `invalid_user_credentials` |

### Schritt 3 — Admin Events prüfen

1. Wechsle zum Tab **Admin events**
2. Hier siehst du die Aktionen, die du als Admin durchgeführt hast

> **Zeigen:** Das "Clear login failures" von eben ist als Admin Event protokolliert. Man kann nachvollziehen, wer wann welchen Account entsperrt hat.

**Diskussionspunkte:**

- Wie lange sollten Events gespeichert werden? (Compliance: oft 90 Tage bis 1 Jahr)
- Kann man Events an ein SIEM weiterleiten? (Ja, über Event Listener SPI)
- Welche Events sind besonders sicherheitsrelevant? (LOGIN_ERROR, UPDATE_PASSWORD, REMOVE_TOTP)

---

## Aufräumen

1. Navigiere zu **Realm settings** → **Security defenses** → **Brute force detection**
2. Setze **Enabled** auf **Disabled** (oder lasse es für die Übung aktiv)
3. Optional: Password Policies entfernen (**Authentication** → **Policies** → **Password policy**)
4. Events-Einstellungen können aktiv bleiben (nützlich für die Übung)
