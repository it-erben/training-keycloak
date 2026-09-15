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

Vom Trainer bekommst du die öffentliche IP deines Domain Controllers, den SHA256-Fingerprint deiner
Workshop-CA, die Datei `workshop-ca.crt` und vier Passwörter: für `hans`, `anna`, das Bind-Konto
`bind` und das Übungskonto `operator`. Der Hostname `dc01.ad.mustertech.test` ist bei allen gleich;
dein lokaler Stack zeigt ihn auf deine IP.

Alle Befehle starten in `workshops/active-directory/lab` des Kurs-Repositories.

> **Hinweis:** Falls die Container einer vorherigen Übung noch laufen, stoppe diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details siehe
> [Troubleshooting](../../labs/assignments/TROUBLESHOOTING.md#container-name-konflikt).

1. `.env` anlegen und deine IP eintragen, die CA-Datei nach `certs/` kopieren.

   **Bash:**

   ```bash
   cp .env.example .env
   cp ~/Downloads/workshop-ca.crt certs/workshop-ca.crt
   ```

   **PowerShell:**

   ```powershell
   Copy-Item .env.example .env
   Copy-Item ~\Downloads\workshop-ca.crt certs\workshop-ca.crt
   ```

2. Stack starten und warten, bis der Setup-Container "Setup complete" meldet:

   ```bash
   docker compose up -d --build
   docker compose logs -f setup
   ```

3. Fingerprint der CA mit dem Wert vom Trainer vergleichen. Erst wenn er passt, geht es weiter:

   ```bash
   docker compose exec ldap-tools openssl x509 -in /certs/workshop-ca.crt -noout -fingerprint -sha256
   ```

4. Bind- und Übungspasswort im Werkzeugcontainer ablegen. Die Dateien landen in `secrets/`
   und bleiben außerhalb von Git:

   ```bash
   docker compose exec -it ldap-tools save-secret bind
   docker compose exec -it ldap-tools save-secret operator
   ```

Danach erreichst du Keycloak unter <http://localhost:8080> (`admin` / `admin`), das Portal
unter <http://localhost:5173> und die API unter <http://localhost:3001>. Der Realm `mustertech`
enthält Rollen, Gruppen und Clients, aber noch keinen LDAP-Provider und keine AD-Benutzer.

## Aufgabe 1: AD-Einträge lesen

Sag vorher, wie der DN von Hans aussieht und welche Gruppen bei ihm direkt eingetragen sind.

**Bash:**

```bash
docker compose exec ldap-tools ldapsearch -LLL -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "bind@ad.mustertech.test" -y /secrets/bind.pw \
  -b "OU=Workshop,DC=ad,DC=mustertech,DC=test" \
  "(sAMAccountName=hans)" dn userPrincipalName objectGUID memberOf
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapsearch -LLL -x -H ldaps://dc01.ad.mustertech.test:636 `
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

```bash
docker compose exec ldap-tools ldapsearch -LLL -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "bind@ad.mustertech.test" -y /secrets/bind.pw \
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
try { Invoke-WebRequest http://localhost:3001/api/urlaubsantraege/alle }
catch { $_.Exception.Response.StatusCode.value__ }
```

Schau dir Annas Access Token an (Portal, **Access Token anzeigen**, dann [jwt.io](https://jwt.io)):
`iat`, `exp` und `realm_access.roles`. Wie lange ist der Token gültig?

## Aufgabe 4: Hans nach Moved verschieben

Sichere vorher drei Werte von Hans in einer Datei: seinen DN aus Aufgabe 1, seine dekodierte
objectGUID und seine Keycloak-Benutzer-ID (Admin-Konsole, **Users → Hans**, ID in der Adresszeile).
Sag voraus, welcher der drei Werte sich durch das Verschieben ändert.

Verschiebe Hans mit dem Übungskonto. Die LDIF-Datei liegt im Werkzeugcontainer bereit:

**Bash:**

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/01-hans-nach-moved.ldif
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 `
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/01-hans-nach-moved.ldif
```

Suche Hans jetzt zweimal mit dem Bind-Konto: einmal unter
`OU=Users,OU=Workshop,DC=ad,DC=mustertech,DC=test`, einmal unter `OU=Workshop,DC=ad,DC=mustertech,DC=test`.
Welche Suche findet ihn, und was zeigt `objectGUID`?

Melde Hans im privaten Fenster an. Schau genau hin, was passiert, und prüfe in der
Admin-Konsole, ob sein Benutzer noch da ist, ob er aktiviert ist und was Keycloak
beim Anmeldeversuch protokolliert (`docker compose logs keycloak`).

Erweitere dann im Provider **Users DN** auf `OU=Workshop,DC=ad,DC=mustertech,DC=test`.
Der Filter bleibt. Speichere, **Sync all users**, Hans erneut anmelden. Vergleiche DN, objectGUID
und Keycloak-Benutzer-ID mit den gesicherten Werten: Was ist gleich geblieben, was nicht?

## Aufgabe 5: Rechte entziehen und Konto sperren

Melde Anna an und kopiere ihren Access Token aus dem Portal in eine Datei `anna.jwt`
(nur der Token, ohne Zeilenumbruch). Merke dir die Uhrzeit und `exp`.

Nimm Anna aus `Teamleitung`:

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
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
$jwt = Get-Content anna.jwt -Raw
$headers = @{ Authorization = "Bearer $jwt" }
try { (Invoke-WebRequest http://localhost:3001/api/urlaubsantraege/alle -Headers $headers).StatusCode }
catch { $_.Exception.Response.StatusCode.value__ }
```

Synchronisiere Gruppen und Benutzer in Keycloak, melde Anna ab und wieder an, klicke
**Alle Anträge (Manager)**. Vergleiche mit Uhrzeit, wann welche Stelle die Änderung gesehen hat:
LDAP (`memberOf` von Anna), Keycloak (Groups von Anna nach dem Sync), der alte Token gegen die API
vor und nach `exp`, der neue Token gegen die API.

Deaktiviere jetzt Hans. Lies vorher seinen aktuellen `userAccountControl`-Wert; die LDIF-Datei
setzt `66050` (Ausgangswert `66048` plus `ACCOUNTDISABLE` = 2). Hans liegt noch in `OU=Moved`:

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/03-hans-deaktivieren.ldif
```

Lass dabei ein Fenster mit angemeldetem Hans offen. Prüfe nacheinander, jeweils mit Blick auf die Uhr:

1. Neuer Login als Hans in einem weiteren privaten Fenster.
2. Das offene Fenster: Seite neu laden, **Mein Profil** klicken.
3. Nach **Sync all users**: Ist Hans in der Admin-Konsole noch **Enabled**?
4. Ein vorher gesicherter Token von Hans gegen `/api/profile` bis `exp`.
5. **Sessions** in der Admin-Konsole: Existiert Hans' Sitzung noch?

## Aufgabe 6: Rücknahme und Auswertung

Nimm alles in dieser Reihenfolge zurück, jeweils mit dem Übungskonto:

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/04-hans-aktivieren.ldif
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/05-anna-in-teamleitung.ldif
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/06-hans-zurueck-nach-users.ldif
```

Setze im Provider **Users DN** wieder auf `OU=Users,OU=Workshop,DC=ad,DC=mustertech,DC=test`.
Entscheide, ob die Strategie rekursiv bleibt, und begründe das. Synchronisiere Gruppen und
Benutzer, beende unter **Sessions** alle Sitzungen der beiden Benutzer.

Nachweis des Ausgangszustands: frischer Login als Hans und als Anna, dann
`/api/urlaubsantraege` für beide und `/api/urlaubsantraege/alle` für beide. Die Statuscodes
müssen denen aus Aufgabe 3 mit rekursiver Strategie entsprechen.

Zum Abschluss beantwortest du für die Auswertung:

1. Wie findet Keycloak einen AD-Benutzer, und wessen Passwort prüft "Test authentication"?
2. Warum reicht `member` allein nicht für Annas Managerrechte, und was ändert die rekursive Strategie?
3. Was bleibt beim OU-Wechsel stabil, und wovon hängt ab, ob Keycloak den Benutzer weiter kennt?
4. Welche Stelle bemerkt Rechteentzug und Deaktivierung zuerst, welche zuletzt, und warum?

Lass den Stack laufen, bis der Trainer die Ergebnisse gesehen hat. Danach:

```bash
docker compose down -v
```
