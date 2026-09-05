# Modul 12: Keycloak und PCI DSS

## Übungsziel

Am Ende dieser Übung hast du:

- Den Realm `mustertech` gegen die Anforderungen von PCI DSS v4.0.1 geprüft und die Abweichungen dokumentiert
- Passwort-Policy, Sperrverhalten und Session-Timeouts auf die PCI-Grenzwerte gesetzt
- MFA für alle Benutzer und für die Admin-Konsole erzwungen
- Einen Helpdesk-Zugang eingerichtet, der nur Passwörter zurücksetzen darf
- Das Audit-Log vollständig konfiguriert und über die Admin-API abgezogen
- Die Rotation von Client-Secrets über eine Client Policy erzwungen
- Die Checkliste mit Soll, Ist und offenen Punkten außerhalb von Keycloak ausgefüllt

**Geschätzte Dauer:** 45-60 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet
- Eine Authenticator-App auf dem Smartphone (FreeOTP, Google Authenticator, Aegis)
- Modul 05 (Flows), 06 (Sessions) und 10a (Sicherheit) sind der fachliche Unterbau

### Umgebung starten

```bash
cd assignments/modul-12-pci-dss
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe
> diese zuerst mit `docker compose down -v` im Verzeichnis der vorherigen Übung.
> Details siehe [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

Warte bis Keycloak bereit ist (~30 Sekunden). Der Realm `mustertech` wird im Stand von
Modul 10b importiert: Passwort-Policy, Brute-Force-Schutz und Events sind aktiv, aber
unterhalb dessen, was PCI DSS verlangt. Die Benutzerpasswörter lauten `Muster1234!`.

Die Compose-Datei schaltet zwei Preview-Features frei (`client-secret-rotation`, `workflows`)
und hebt erfolgreiche Login-Events auf `INFO`, damit sie im Container-Log erscheinen.

### Was PCI DSS für dieses Lab bedeutet

PCI DSS gilt für Systeme, die Karteninhaberdaten speichern, verarbeiten oder übertragen, und
für alle Systeme, die deren Sicherheit beeinflussen. Ein Identity Provider, der den Zugang zu
diesen Systemen steuert, gehört dazu. Das Lab arbeitet die Anforderungen ab, die sich in
Keycloak einstellen lassen. Was die Organisation zusätzlich regeln muss, landet in der letzten
Spalte der [Checkliste](checkliste.md).

---

## Teil 1: Ist-Aufnahme

### Schritt 1.1: Checkliste öffnen

Öffne `checkliste.md` in deinem Editor. Jede Zeile nennt die Anforderung, den Sollwert und
den Ort in der Admin-Konsole.

### Schritt 1.2: Ist-Werte eintragen

Gehe die Zeilen 8.2.8, 8.3.4, 8.3.6, 8.3.7, 8.3.9, 8.4.2, 10.2.1 und 10.5.1 durch und trage
ein, was der Realm `mustertech` aktuell hat:

| Ort | Was ablesen |
| --- | --- |
| **Authentication** → **Policies** → **Password policy** | Minimum length, Not recently used, Expire password |
| **Realm settings** → **Security defenses** → **Brute force detection** | Max login failures, Wait increment |
| **Realm settings** → **Sessions** | SSO Session Idle |
| **Authentication** → **Flows** → `browser-mustertech` | Requirement des OTP-Subflows |
| **Realm settings** → **Events** | Expiration, Admin events, Include representation |

Sieben der acht Zeilen liegen unter dem Soll; 10.2.1 ist bereits erfüllt. Der Rest des Labs
schließt die Lücken in der Reihenfolge der Checkliste.

---

## Teil 2: Passwörter (8.3.5 bis 8.3.9)

### Schritt 2.1: Policy verschärfen

1. Navigiere zu **Authentication** → **Policies** → **Password policy**
2. Ändere **Minimum length** auf `12`
3. Klicke auf **Add policy** und ergänze:

| Policy | Wert | Anforderung |
| --- | --- | --- |
| **Not recently used** | `4` | 8.3.7: keines der letzten vier Passwörter |
| **Expire password** | `90` | 8.3.9: Wechsel alle 90 Tage |

4. Klicke auf **Save**

`Digits`, `Uppercase`, `Lowercase`, `Special characters`, `Not username` und `Not email` sind
bereits aktiv.

> **Konzept: Wirkung der Policy** - Eine Policy greift erst bei der nächsten
> Passwortänderung. Bestehende Passwörter bleiben gültig, bis `Expire password` sie
> abläuft oder ein Admin die Aktion `Update Password` setzt.

### Schritt 2.2: Erstpasswort einmalig (8.3.5)

1. Navigiere zu **Users** → **Add user**
2. Username `lisa.audit`, E-Mail `lisa.audit@mustertech.de`, Vor- und Nachname beliebig
3. Klicke auf **Create**, wechsle zum Tab **Credentials** → **Set password**
4. Passwort `Erstpasswort2026!`, **Temporary** auf `On`, **Save**

Melde dich in einem privaten Browserfenster unter
`http://localhost:8080/realms/mustertech/account/` als `lisa.audit` an. Keycloak verlangt
sofort ein neues Passwort. Versuche eines mit 10 Zeichen: die Policy lehnt es ab.

---

## Teil 3: Sperrverhalten (8.3.4)

PCI DSS verlangt eine Sperre nach höchstens zehn Fehlversuchen, die mindestens 30 Minuten hält
oder bis ein Admin sie aufhebt.

### Schritt 3.1: Parameter setzen

1. Navigiere zu **Realm settings** → **Security defenses** → **Brute force detection**
2. Setze:

| Parameter | Wert |
| --- | --- |
| **Brute Force Mode** | Lockout temporarily |
| **Max login failures** | `10` |
| **Wait increment** | `30` Minutes |
| **Max wait** | `30` Minutes |
| **Failure reset time** | `12` Hours |

3. Klicke auf **Save**

`Wait increment` gleich `Max wait` bedeutet: die erste Sperre dauert bereits 30 Minuten. Die
Variante **Lockout permanently after temporary lockout** erfüllt die Anforderung ebenfalls;
sie verlagert die Freigabe vollständig zum Admin.

### Schritt 3.2: Sperre auslösen und aufheben

1. Melde dich im privaten Fenster zehnmal als `hans.mueller` mit falschem Passwort an
2. Der elfte Versuch mit dem richtigen Passwort scheitert ebenfalls
3. Navigiere zu **Users** → `hans.mueller`: oben steht der Hinweis auf die Sperre
4. Klicke auf **Unlock**

---

## Teil 4: Sessions (8.2.8)

1. Navigiere zu **Realm settings** → **Sessions**
2. Setze **SSO Session Idle** auf `15` Minutes und **Client Session Idle** auf `15` Minutes
3. Unter **Login settings** setze **Login timeout** auf `5` Minutes
4. Klicke auf **Save**

Nach 15 Minuten ohne Aktivität muss sich der Benutzer neu authentifizieren. Die Anwendung selbst
muss denselben Timeout einhalten; ein Access Token mit 5 Minuten Laufzeit (Modul 06) trägt dazu
bei.

---

## Teil 5: MFA erzwingen (8.4, 8.5)

Der Flow `browser-mustertech` fragt OTP nur, wenn der Benutzer eines eingerichtet hat
(`Conditional`). PCI DSS verlangt MFA für jeden Zugang, ohne Ausnahme.

### Schritt 5.1: OTP Form auf Required

1. Navigiere zu **Authentication** → **Flows** → `browser-mustertech`
2. Beim Subflow **browser-mustertech Browser - Conditional OTP** setze das Requirement auf
   **Disabled**
3. Beim Subflow **browser-mustertech forms** klicke auf **+** → **Add step** → **OTP Form**
   → **Add**
4. Setze das Requirement des neuen Schritts auf **Required**

Melde dich im privaten Fenster als `anna.schmidt` am Account-Portal an. Keycloak verlangt die
Einrichtung eines OTP, bevor die Anmeldung abgeschlossen ist: ein `Required` OTP Form setzt
bei Benutzern ohne OTP automatisch die Aktion `Configure OTP`.

### Schritt 5.2: OTP-Policy härten (8.5.1)

1. Navigiere zu **Authentication** → **Policies** → **OTP Policy**
2. Prüfe: **OTP Type** `Time Based`, **Look ahead window** `1`, **Reusable token** `Off`
3. Klicke auf **Save**, falls etwas abweicht

`Look ahead window` begrenzt, wie viele Zeitfenster um die aktuelle Zeit ein Code gilt. Ein
abgefangener Code ist nach 30 Sekunden wertlos; mit `Reusable token` Off auch innerhalb des
Fensters nur einmal.

### Schritt 5.3: Admin-Konsole absichern (8.4.1)

Der Realm `master` hat noch den Standard-Flow.

1. Wechsle über den Realm-Selector zu **master**
2. Navigiere zu **Authentication** → **Flows** → `browser` → **Action** → **Duplicate**,
   Name `browser-mfa`
3. Im neuen Flow: Subflow **browser-mfa Browser - Conditional OTP** auf **Disabled**,
   in **browser-mfa forms** einen Schritt **OTP Form** mit **Required** ergänzen
4. **Action** → **Bind flow** → **Browser flow** → **Save**

Melde dich ab und wieder als `admin` an. Keycloak verlangt jetzt die Einrichtung eines OTP.

> **Hinweis:** Bewahre den QR-Code-Eintrag in der Authenticator-App bis zum Ende des Labs.
> Geht er verloren, hilft nur `docker compose down -v` und ein Neustart des Labs.

---

## Teil 6: Helpdesk mit minimalen Rechten (7.2.1)

Ein Helpdesk soll Passwörter zurücksetzen, sonst nichts. Die Rolle `realm-admin` wäre dafür
zu breit. Admin Permissions erlauben die Vergabe pro Ressource und Operation.

### Schritt 6.1: Admin Permissions aktivieren

1. Wechsle zurück in den Realm **mustertech**
2. Navigiere zu **Realm settings** → **General**, schalte **Admin Permissions** auf `On`,
   **Save**
3. Im linken Menü erscheint der Eintrag **Permissions**

### Schritt 6.2: Helpdesk-Benutzer anlegen

1. **Realm roles** → **Create role**: Name `helpdesk`
2. **Users** → **Add user**: Username `tom.helpdesk`, E-Mail `tom.helpdesk@mustertech.de`
3. Tab **Credentials**: Passwort `Helpdesk2026!!`, **Temporary** `Off`
4. Tab **Role mapping** → **Assign role**:
   - Filter **Filter by realm roles**: `helpdesk`
   - Filter **Filter by clients**: `query-users` des Clients `realm-management`

`query-users` öffnet nur den Bereich **Users** in der Konsole. Was `tom.helpdesk` dort darf,
bestimmt allein die Permission aus dem nächsten Schritt.

### Schritt 6.3: Permission anlegen

1. Navigiere zu **Permissions** → **Create permission** → **Users**
2. Fülle aus:

| Feld | Wert |
| --- | --- |
| **Name** | `helpdesk-reset-password` |
| **Authorization scopes** | `view`, `reset-password` |
| **Enforce access to** | All Users |
| **Policies** | **Create new policy** → Type **Role** → Name `helpdesk-role`, Role `helpdesk` |

3. Klicke auf **Save**

### Schritt 6.4: Grenze testen

Melde dich im privaten Fenster unter `http://localhost:8080/admin/mustertech/console/` als
`tom.helpdesk` an. Nach der OTP-Einrichtung siehst du nur den Bereich **Users**. Öffne
`hans.mueller`: der Tab **Credentials** erlaubt **Reset password**; die Felder unter
**Details** sind nicht änderbar, **Delete** fehlt.

> **Konzept: Least Privilege** - `query-users` gibt den Einstieg, die Permission gibt die
> Operationen. Ohne `view` wäre die Benutzerliste leer, ohne `reset-password` griffe der
> Fallback auf `manage`, und der ist nicht vergeben.

---

## Teil 7: Audit-Log (10.2, 10.5)

### Schritt 7.1: Events vollständig

1. Navigiere zu **Realm settings** → **Events** → **User events settings**
2. **Save events** `On`, **Expiration** `90` Days
3. **Event listeners**: `jboss-logging` muss enthalten sein
4. **Saved types**: leer lassen. Eine leere Liste bedeutet, dass Keycloak alle Typen speichert
5. **Save**, dann Tab **Admin events settings**: **Save events** `On`,
   **Include representation** `On`, **Save**

PCI DSS verlangt zwölf Monate Aufbewahrung, davon drei Monate sofort verfügbar. Die Datenbank
hält 90 Tage; `jboss-logging` schreibt jedes Event zusätzlich nach stdout, von wo es das
Log-System der Organisation für den Rest des Jahres übernimmt.

### Schritt 7.2: Events im Container-Log

```bash
docker compose logs assignment-keycloak | grep "type=LOGIN"
```

Jede Zeile trägt `realmId`, `userId`, `ipAddress`, `clientId` und bei Fehlern `error`. Das
sind die Felder, die 10.2.2 verlangt: Wer, Was, Wann, Erfolg, Herkunft, Ziel.

### Schritt 7.3: Events über die Admin-API abziehen

```bash
docker exec assignment-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master --user admin --password admin
docker exec assignment-keycloak /opt/keycloak/bin/kcadm.sh get events \
  -r mustertech --limit 5
docker exec assignment-keycloak /opt/keycloak/bin/kcadm.sh get admin-events \
  -r mustertech --limit 5
```

Da der Admin jetzt ein OTP hat, fragt `kcadm.sh` beim ersten Befehl nach dem aktuellen Code.
Die zweite Ausgabe zeigt zu jeder Admin-Aktion `operationType`, `resourcePath` und die
gesendete `representation`: das Passwort-Reset aus Teil 6 steht dort mit `tom.helpdesk` als
`authDetails.userId`.

---

## Teil 8: Client-Secrets rotieren (8.6.3)

`sync-service` authentifiziert sich mit einem Client-Secret. PCI DSS verlangt, dass solche
Zugangsdaten regelmäßig wechseln und ein Wechsel den Betrieb nicht unterbricht.

### Schritt 8.1: Profil mit Executor

1. Navigiere zu **Realm settings** → **Client policies** → **Profiles** → **Create client profile**
2. Name `secret-rotation`, **Save**
3. **Add executor** → **Executor type** `secret-rotation`:

| Feld | Wert | Bedeutung |
| --- | --- | --- |
| **Secret Expiration** | `604800` | Secret gilt 7 Tage |
| **Rotated Secret Expiration** | `172800` | Altes Secret nach Rotation noch 2 Tage gültig |
| **Remain Expiration Time** | `86400` | Ab 1 Tag vor Ablauf rotiert jede Client-Änderung |

4. **Add**

### Schritt 8.2: Policy binden

1. Tab **Policies** → **Create client policy**: Name `rotate-confidential-secrets`, **Save**
2. **Add condition** → **Condition type** `client-access-type` → **Client Access Type**
   `confidential` → **Add**
3. **Add client profile** → `secret-rotation` → **Add**

### Schritt 8.3: Rotation auslösen

1. Navigiere zu **Clients** → `sync-service` → **Credentials**
2. Klicke auf **Regenerate**

Keycloak zeigt jetzt zwei Secrets: das neue mit Ablaufdatum und das rotierte mit seiner
Restlaufzeit. Der Sync-Service kann in den zwei Tagen umgestellt werden, ohne dass ein Login
fehlschlägt. Das Regenerieren lässt sich über die Admin-API aus einem Secret-Manager heraus
auslösen.

---

## Bonus: Inaktive Konten (8.2.6)

Keycloak speichert keinen Zeitpunkt der letzten Anmeldung am Benutzer. Der Workflow-Engine
(Preview) zählt stattdessen ab dem letzten `user-authenticated`-Event.

1. Navigiere zu **Workflows** → **Create**
2. Füge ein:

```yaml
name: Inaktive Konten sperren
on: user-authenticated
schedule:
  after: 1h
  batch-size: 100
concurrency:
  restart-in-progress: true
steps:
  - uses: notify-user
    after: 76d
    with:
      subject: "Konto wird in 14 Tagen gesperrt"
      message: "Ohne Anmeldung wird dein Konto in 14 Tagen deaktiviert."
  - uses: disable-user
    after: 14d
```

3. **Save**

Jede Anmeldung setzt den Zähler zurück (`restart-in-progress`). Nach 76 Tagen ohne Anmeldung
geht eine Mail an Mailpit (`http://localhost:8025`), nach 90 Tagen ist das Konto deaktiviert.
Die Grenze der Methode: Benutzer, die sich nach dem Anlegen des Workflows nie angemeldet haben,
erfasst der Zeitplan erst über `schedule`.

---

## Teil 9: Checkliste abschließen

Trage die Werte aus den Teilen 2 bis 8 in die Spalte „Ist nachher" ein. Fülle die Spalte
„Außerhalb von Keycloak" für die Zeilen 8.2.1, 8.2.5, 10.5.1, 10.6, 4.2.1 und 6.3.3: dort
bleibt die Organisation in der Pflicht, auch wenn Keycloak korrekt konfiguriert ist.

---

## Aufräumen

```bash
docker compose down -v
```

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Den Realm gegen PCI DSS v4.0.1 geprüft und Abweichungen dokumentiert
- [x] Passwort-Policy, Sperrverhalten und Sessions auf die Grenzwerte gesetzt
- [x] MFA für Benutzer und Admins ohne Ausnahme erzwungen
- [x] Einen Helpdesk-Zugang mit Admin Permissions auf `reset-password` beschränkt
- [x] Das Audit-Log vollständig konfiguriert und über die Admin-API abgezogen
- [x] Client-Secrets über eine Client Policy rotiert

---

## Troubleshooting

Siehe zentrales Troubleshooting: [PCI DSS / Admin Permissions](../TROUBLESHOOTING.md#admin-permissions-und-client-policies)

---

## Weiterführende Ressourcen

- [PCI Security Standards Council: Document Library](https://www.pcisecuritystandards.org/document_library/)
- [Keycloak Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/) — Abschnitte
  Fine-grained admin permissions, Client policies, Auditing and events, Workflows
