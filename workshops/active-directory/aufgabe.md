# Active Directory: Vom Verzeichnis bis zur API

## Übungsziel

Am Ende dieser Übung hast du:

- AD-Einträge über LDAPS gelesen und DN, UPN, objectGUID und Mitgliedschaften zugeordnet
- Dein lokales Keycloak per LDAPS mit Zertifikatsprüfung an dein Active Directory angebunden
- Direkte und verschachtelte Gruppen zu den Rollen `mitarbeiter` und `manager` gemacht
- Einen Benutzer in eine andere OU verschoben und die Folgen für Suchbasis und Import erklärt
- Rechteentzug und Kontodeaktivierung getrennt an LDAP, Keycloak, Sitzung und API beobachtet
- Alle Änderungen zurückgenommen und den Ausgangszustand nachgewiesen

Du bekommst einen eigenen Domain Controller. Niemand sonst arbeitet in deinem Verzeichnis, du kannst
also alles ausprobieren und zum Schluss zurücksetzen.

## Voraussetzungen

Du bekommst eine eigene AD-IP, die Datei `workshop-ca.crt` samt SHA256-Fingerprint und
vier Passwörter: für `hans`, `anna`, `bind` und `operator`. Der Hostname
`dc01.ad.mustertech.test` ist bei allen gleich; dein lokaler Stack zeigt ihn auf deine IP.
Verwende nur dein eigenes Teilnehmerpaket.

### Auf dem vorbereiteten Windows-Schulungsrechner

Öffne auf dem Desktop `AD-Workshop/START-HIER.html` und eine **Windows PowerShell**.
Die PowerShell-Blöcke dieser Anleitung funktionieren auch mit Windows PowerShell 5.1.
Führe sie auf dem Windows-Rechner aus, nicht in Git Bash oder in einer zusätzlichen WSL-Shell.
Bei mehrzeiligen PowerShell-Befehlen muss der Backtick das letzte Zeichen der Zeile sein.

```powershell
Set-Location "$HOME/Desktop/AD-Workshop/workshops/active-directory/lab"
docker info --format '{{.OSType}}'
docker compose version
```

Erwartet werden `linux` und eine Compose-Version. Docker Desktop muss laufen.
Im Paket sind `.env`, `certs/workshop-ca.crt`, `secrets/bind.pw` und `secrets/operator.pw`
bereits vorbereitet. Die vier Passwörter stehen in `AD-Workshop/zugangsdaten.txt`.
Überschreibe diese Dateien nicht mit denen eines anderen Teilnehmers.

Prüfe die Verbindung zu deiner AD-IP aus `.env`:

```powershell
$adIp = ((Get-Content .env | Where-Object { $_ -match '^AD_PUBLIC_IP=' }) -split '=', 2)[1].Trim()
Test-NetConnection $adIp -Port 636
```

Bei `TcpTestSucceeded : False` informiere den Trainer mit Rechnernummer und AD-IP.
Dieser Test prüft nur TCP. Zertifikat und Anmeldung werden anschließend gesondert geprüft.

### Bei einem frischen Git-Clone

Überspringe diesen Abschnitt, wenn du das vorbereitete Desktop-Paket verwendest.
Wechsle im Kurs-Repository nach `workshops/active-directory/lab`. Kopiere `.env.example`
nach `.env`, ersetze dort `AD_PUBLIC_IP` durch deine IP und lege deine CA-Datei in `certs/` ab:

**Bash:**

```bash
cp .env.example .env
cp ~/Downloads/workshop-ca.crt certs/workshop-ca.crt
```

**PowerShell:**

```powershell
Copy-Item .env.example .env
Copy-Item "$HOME/Downloads/workshop-ca.crt" certs/workshop-ca.crt
notepad .env
```

### Stack starten und prüfen

Alle folgenden Befehle starten im Verzeichnis `workshops/active-directory/lab`.

> **Hinweis:** Eine vorherige Übung kann die Ports 8080, 5173 oder 3001 belegen.
> Halte sie mit `docker compose stop` in ihrem eigenen Lab-Verzeichnis an; ihre Daten bleiben erhalten.
> Die laufenden Container zeigt `docker ps`. Weitere Hinweise stehen im
> [Troubleshooting](../../labs/assignments/TROUBLESHOOTING.md#container-name-konflikt).

Die folgenden einzeiligen Docker-Befehle funktionieren in Bash und PowerShell:

```bash
docker compose up -d --build --wait --wait-timeout 180
docker compose ps -a
docker compose logs --tail 30 setup
```

Erwartet: `Setup complete` im Setup-Log. Der einmalige `setup`-Container darf danach mit
Exit-Code `0` beendet sein. Bei einem Fehler lies `docker compose logs --tail 80 keycloak setup`.
Fahre erst fort, wenn Keycloak bereit ist und das Setup erfolgreich war.

Vergleiche den CA-Fingerprint mit deinem Teilnehmerpaket:

```bash
docker compose exec ldap-tools openssl x509 -in /certs/workshop-ca.crt -noout -fingerprint -sha256
```

Nur beim frischen Clone: Lege anschließend die beiden Werkzeugpasswörter ab. Beim vorbereiteten
Desktop-Paket ist das bereits erledigt. Die Eingabe bleibt unsichtbar:

```bash
docker compose exec -it ldap-tools save-secret bind
docker compose exec -it ldap-tools save-secret operator
```

Öffne die Admin-Konsole <http://localhost:8080> (`admin` / `admin`) in Chrome.
Das Portal läuft unter <http://localhost:5173>, die API unter <http://localhost:3001>.
Der Realm `mustertech` enthält Rollen, Gruppen und Clients; LDAP-Provider und AD-Benutzer
richtest du in der Übung selbst ein.

Nutze für Hans **Edge InPrivate**, für Anna **Firefox Privat**. Private Fenster desselben Browsers
teilen ihre Sitzung. Für einen frischen Login schließe alle privaten Fenster dieses Browsers
und öffne ein neues. Bewahre Tokens vor dem Schließen wie in Aufgabe 5 beschrieben auf.
Passwörter und vollständige Tokens gehören weder in Git noch in gemeinsame Chats.

## Aufgabe 1: AD-Einträge lesen

Sag vorher, wie der DN von Hans aussieht und welche Gruppen bei ihm direkt eingetragen sind.

**Bash:**

```bash
docker compose exec ldap-tools ldapsearch -LLL -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "bind@ad.mustertech.test" -y /secrets/bind.pw \
  -b "OU=Workshop,DC=ad,DC=mustertech,DC=test" \
  "(sAMAccountName=hans)" dn userPrincipalName objectGUID memberOf
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapsearch -LLL -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "bind@ad.mustertech.test" -y /secrets/bind.pw `
  -b "OU=Workshop,DC=ad,DC=mustertech,DC=test" `
  "(sAMAccountName=hans)" dn userPrincipalName objectGUID memberOf
```

`objectGUID::` mit zwei Doppelpunkten ist Base64 für 16 Binärbytes. Der Werkzeugcontainer
wandelt den Wert in die Schreibweise um, die Keycloak später als `LDAP_ID` zeigt:

```bash
docker compose exec ldap-tools decode-guid "<Base64-Wert aus der Ausgabe>"
```

Wiederhole die Suche für `anna`. Von beiden brauchst du später DN, UPN, die dekodierte objectGUID
und die direkten Gruppen aus `memberOf`; behalte die Ausgaben im Terminal oder in einer Datei.

Lies danach die Gruppe `Manager`:

**Bash:**

```bash
docker compose exec ldap-tools ldapsearch -LLL -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "bind@ad.mustertech.test" -y /secrets/bind.pw \
  -b "OU=Groups,OU=Workshop,DC=ad,DC=mustertech,DC=test" "(cn=Manager)" member
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapsearch -LLL -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "bind@ad.mustertech.test" -y /secrets/bind.pw `
  -b "OU=Groups,OU=Workshop,DC=ad,DC=mustertech,DC=test" "(cn=Manager)" member
```

Kläre für dich: Warum steht `Manager` bei Anna nicht in `memberOf`, obwohl sie später Managerrechte
bekommen soll? Welche Kette führt von Anna zu `Manager`?

## Aufgabe 2: Keycloak über LDAPS verbinden

Öffne in der Admin-Konsole den Realm `mustertech`, dann **User federation → Add Ldap providers**.
Sag vor dem Speichern voraus, ob "Test connection" und "Test authentication" mit dem Bind-Konto
funktionieren und ob danach schon Benutzer in Keycloak sichtbar sind.

| Feld                    | Wert                                                   |
| ----------------------- | ------------------------------------------------------ |
| UI display name         | `ad-workshop`                                          |
| Vendor                  | Active Directory                                       |
| Connection URL          | `ldaps://dc01.ad.mustertech.test:636`                  |
| Use Truststore SPI      | Always                                                 |
| Bind type               | simple                                                 |
| Bind DN                 | `bind@ad.mustertech.test`                              |
| Bind credentials        | Passwort von `bind`                                    |
| Edit mode               | READ_ONLY                                              |
| Users DN                | `OU=Users,OU=Workshop,DC=ad,DC=mustertech,DC=test`     |
| Username LDAP attribute | `userPrincipalName`                                    |
| RDN LDAP attribute      | `cn`                                                   |
| UUID LDAP attribute     | `objectGUID`                                           |
| User object classes     | `person, organizationalPerson, user`                   |
| User LDAP filter        | siehe unten                                            |
| Search scope            | Subtree                                                |
| Import users            | On                                                     |
| Sync Registrations      | Off                                                    |

Der Filter beschränkt den Import auf die beiden Testbenutzer. Bind- und Übungskonto dürfen nie
im Portal landen:

```text
(|(sAMAccountName=hans)(sAMAccountName=anna))
```

Klicke **Test connection**, dann **Test authentication**, dann **Save**. Prüfe unter **Mappers**,
welche Mapper Keycloak für den Vendor Active Directory angelegt hat, und lies nach, was der
Mapper `MSAD account controls` laut seiner Beschreibung tut.

Klicke oben rechts **Action → Sync all users**. Öffne **Users**: Wie heißt der Benutzername von
Hans in Keycloak, und was steht bei ihm unter **Attributes** in `LDAP_ID`? Vergleiche mit der
dekodierten objectGUID aus Aufgabe 1.

Melde dich jetzt im **privaten Browserfenster** unter <http://localhost:5173> als
`hans@ad.mustertech.test` mit dem Passwort von Hans an. Klicke im Portal
**Mein Profil** und **Meine Urlaubsanträge**. Sag die beiden Statuscodes vorher voraus.

Kläre: Welche Rollen zeigt **Mein Profil**, und warum antwortet `/api/urlaubsantraege`
so, wie es antwortet, obwohl die Anmeldung gegen AD funktioniert hat?

## Aufgabe 3: Gruppen und verschachtelte Gruppen

Lege unter **User federation → ad-workshop → Mappers → Add mapper** den Gruppen-Mapper an:

| Feld                            | Wert                                                |
| ------------------------------- | --------------------------------------------------- |
| Name                            | `ad-groups`                                         |
| Mapper type                     | group-ldap-mapper                                   |
| LDAP Groups DN                  | `OU=Groups,OU=Workshop,DC=ad,DC=mustertech,DC=test` |
| Group Name LDAP Attribute       | `cn`                                                |
| Group Object Classes            | `group`                                             |
| Preserve Group Inheritance      | Off                                                 |
| Membership LDAP Attribute       | `member`                                            |
| Membership Attribute Type       | DN                                                  |
| Membership User LDAP Attribute  | `cn`                                                |
| Mode                            | READ_ONLY                                           |
| User Groups Retrieve Strategy   | LOAD_GROUPS_BY_MEMBER_ATTRIBUTE                     |
| Groups Path                     | `/`                                                 |

Speichere, klicke beim Mapper **Action → Sync LDAP groups to Keycloak** und beim Provider
**Action → Sync all users**. Öffne **Groups**: Die Gruppen `Mitarbeiter`, `Teamleitung` und
`Manager` gab es schon aus dem Realm-Import; `Mitarbeiter` trägt die Rolle `mitarbeiter`, `Manager`
die Rolle `manager`. Prüfe bei Anna unter **Groups** und **Role mapping** (mit geerbten Rollen),
was sie jetzt hat.

Melde Anna im privaten Fenster an und klicke **Alle Anträge (Manager)**. Sag den Statuscode
vorher voraus. Dieselbe Vorhersage machst du gleich noch dreimal: Anna mit rekursiver Strategie,
Hans und ein Aufruf ohne Token.

Stelle danach im Mapper **User Groups Retrieve Strategy** auf
`LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY`, speichere, synchronisiere Gruppen und Benutzer
erneut. Melde Anna ab und wieder an, damit ein neuer Token entsteht, und klicke erneut.

Den Fall ohne Token prüfst du in der Shell:

**Bash:**

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3001/api/urlaubsantraege/alle
```

**PowerShell:**

```powershell
curl.exe -s -o NUL -w "%{http_code}" http://localhost:3001/api/urlaubsantraege/alle
```

Schau dir Annas Access Token an (Portal, **Access Token anzeigen**): `iat`, `exp` und
`realm_access.roles`. Kopiere nur den Token in die Zwischenablage und dekodiere die Nutzdaten
lokal in PowerShell. Diese Anzeige prüft keine Signatur; das erledigt die API bei jedem Aufruf.

```powershell
$jwt = (Get-Clipboard -Raw).Trim()
$payload = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
$payload = $payload.PadRight([int]([Math]::Ceiling($payload.Length / 4.0) * 4), '=')
$claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
$claims | Select-Object iat, exp, realm_access
[DateTimeOffset]::FromUnixTimeSeconds($claims.exp).ToLocalTime()
$claims.exp - $claims.iat
```

Die letzte Zeile zeigt die Gültigkeitsdauer in Sekunden. Unter Bash kannst du die angezeigten
Werte direkt vergleichen; zum Lesen ist kein externer Token-Dienst nötig.

## Aufgabe 4: Hans nach Moved verschieben

Sichere vorher drei Werte von Hans in einer Datei: seinen DN aus Aufgabe 1, seine dekodierte
objectGUID und seine Keycloak-Benutzer-ID (Admin-Konsole, **Users → Hans**, ID in der Adresszeile).
Sag voraus, welcher der drei Werte sich durch das Verschieben ändert.

Verschiebe Hans mit dem Übungskonto. Die LDIF-Datei liegt im Werkzeugcontainer bereit:

**Bash:**

```bash
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/01-hans-nach-moved.ldif
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/01-hans-nach-moved.ldif
```

Suche Hans jetzt zweimal mit dem Bind-Konto: einmal unter
`OU=Users,OU=Workshop,DC=ad,DC=mustertech,DC=test`, einmal unter `OU=Workshop,DC=ad,DC=mustertech,DC=test`.
Welche Suche findet ihn, und was zeigt `objectGUID`?

Starte einen frischen Login als Hans (alle Edge-InPrivate-Fenster vorher schließen).
Schau genau hin, was passiert, und prüfe in der
Admin-Konsole, ob sein Benutzer noch da ist, ob er aktiviert ist und was Keycloak
beim Anmeldeversuch protokolliert (`docker compose logs keycloak`).

Erweitere dann im Provider **Users DN** auf `OU=Workshop,DC=ad,DC=mustertech,DC=test`.
Der Filter bleibt. Speichere, **Sync all users**, Hans erneut anmelden. Vergleiche DN, objectGUID
und Keycloak-Benutzer-ID mit den gesicherten Werten: Was ist gleich geblieben, was nicht?

## Aufgabe 5: Rechte entziehen und Konto sperren

Melde Anna frisch an und sichere ihren aktuellen Access Token aus dem Portal in `anna.jwt`.
Kopiere dafür nur den Token in die Zwischenablage. Merke dir die Uhrzeit und `exp`.

**PowerShell:**

```powershell
$token = (Get-Clipboard -Raw).Trim()
[IO.File]::WriteAllText((Join-Path (Get-Location) 'anna.jwt'), $token, [Text.UTF8Encoding]::new($false))
```

**Bash:**

```bash
read -r -s -p 'Annas Access Token: ' token; printf '\n'
printf '%s' "$token" > anna.jwt
unset token
```

Lass diese Datei beim späteren Anmelden unverändert, damit du wirklich den alten Token testest.

Nimm Anna aus `Teamleitung`:

**Bash:**

```bash
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/02-anna-aus-teamleitung.ldif
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/02-anna-aus-teamleitung.ldif
```

Teste den alten Token gegen die API, mehrmals bis nach `exp`:

**Bash:**

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $(cat anna.jwt)" \
  http://localhost:3001/api/urlaubsantraege/alle
```

**PowerShell:**

```powershell
$jwt = (Get-Content anna.jwt -Raw).Trim()
curl.exe -s -o NUL -w "%{http_code}" -H "Authorization: Bearer $jwt" `
  http://localhost:3001/api/urlaubsantraege/alle
```

Synchronisiere Gruppen und Benutzer in Keycloak, melde Anna ab und wieder an, klicke
**Alle Anträge (Manager)**. Vergleiche mit Uhrzeit, wann welche Stelle die Änderung gesehen hat:
LDAP (`memberOf` von Anna), Keycloak (Groups von Anna nach dem Sync), der alte Token gegen die API
vor und nach `exp`, der neue Token gegen die API.

Melde Hans vor der Deaktivierung in Edge InPrivate an, sichere seinen Access Token mit demselben
Verfahren in **`hans.jwt`** und notiere `exp`. Lass dieses Fenster geöffnet.
Lies seinen aktuellen `userAccountControl`-Wert mit der LDAP-Suche aus Aufgabe 1;
verwende die breite Suchbasis `OU=Workshop,DC=ad,DC=mustertech,DC=test` und ergänze das Attribut
`userAccountControl`. Deaktiviere danach Hans; die LDIF-Datei
setzt `66050` (Ausgangswert `66048` plus `ACCOUNTDISABLE` = 2). Hans liegt noch in `OU=Moved`:

**Bash:**

```bash
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/03-hans-deaktivieren.ldif
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/03-hans-deaktivieren.ldif
```

Lass dabei ein Fenster mit angemeldetem Hans offen. Prüfe nacheinander, jeweils mit Blick auf die Uhr:

1. Neuer Login als Hans in **Chrome Inkognito**. Das offene Edge-InPrivate-Fenster bleibt bestehen.
2. Das offene Fenster: Seite neu laden, **Mein Profil** klicken.
3. Nach **Sync all users**: Ist Hans in der Admin-Konsole noch **Enabled**?
4. Den gesicherten Token aus `hans.jwt` gegen `/api/profile` bis `exp` testen, analog zu Anna.
5. **Sessions** in der Admin-Konsole: Existiert Hans' Sitzung noch?

## Aufgabe 6: Rücknahme und Auswertung

Nimm alles in dieser Reihenfolge zurück, jeweils mit dem Übungskonto:

**Bash:**

```bash
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/04-hans-aktivieren.ldif
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/05-anna-in-teamleitung.ldif
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/06-hans-zurueck-nach-users.ldif
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/04-hans-aktivieren.ldif
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/05-anna-in-teamleitung.ldif
docker compose exec ldap-tools ldapmodify -x -o nettimeout=10 -H ldaps://dc01.ad.mustertech.test:636 `
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/06-hans-zurueck-nach-users.ldif
```

Setze im Provider **Users DN** wieder auf `OU=Users,OU=Workshop,DC=ad,DC=mustertech,DC=test`.
Stelle für den Vergleich die rekursive Strategie aus Aufgabe 3 ein. Synchronisiere Gruppen und
Benutzer, beende unter **Sessions** alle Sitzungen der beiden Benutzer.

Nachweis des Ausgangszustands: frischer Login als Hans und als Anna, dann
`/api/urlaubsantraege` für beide und `/api/urlaubsantraege/alle` für beide. Die Statuscodes
müssen denen aus Aufgabe 3 mit rekursiver Strategie entsprechen.

Zum Abschluss beantwortest du für die Auswertung:

1. Wie findet Keycloak einen AD-Benutzer, und wessen Passwort prüft "Test authentication"?
2. Warum reicht `member` allein nicht für Annas Managerrechte, und was ändert die rekursive Strategie?
3. Was bleibt beim OU-Wechsel stabil, und wovon hängt ab, ob Keycloak den Benutzer weiter kennt?
4. Welche Stelle bemerkt Rechteentzug und Deaktivierung zuerst, welche zuletzt, und warum?

Lass den Stack laufen, bis der Trainer die Ergebnisse gesehen hat. Zum Pausieren genügt
`docker compose stop`. Wenn du die Übungsdaten bewusst verwerfen möchtest, führe ausschließlich
im AD-Lab-Verzeichnis aus:

```bash
docker compose down -v
```

Entferne anschließend die lokalen Dateien `anna.jwt` und `hans.jwt`, wenn du sie angelegt hast.
