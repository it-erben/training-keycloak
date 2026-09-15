# Active Directory: Vom Verzeichnis bis zur API

## Übungsziel

Am Ende dieser Übung habt ihr:

- AD-Einträge eures Teams über LDAPS gelesen und DN, UPN, objectGUID und Mitgliedschaften zugeordnet
- Euer lokales Keycloak per LDAPS mit Zertifikatsprüfung an das Active Directory angebunden
- Direkte und verschachtelte Gruppen zu den Rollen `mitarbeiter` und `manager` gemacht
- Einen Benutzer in eine andere OU verschoben und die Folgen für Suchbasis und Import erklärt
- Rechteentzug und Kontodeaktivierung getrennt an LDAP, Keycloak, Sitzung und API beobachtet
- Alle Änderungen zurückgenommen und den Ausgangszustand nachgewiesen

**Dauer:** 90 Minuten in Zweiergruppen. Eine Person bedient den Stack, ihr wechselt euch bei den Versuchen ab.

## Voraussetzungen

Vom Trainer bekommt ihr einen Zettel mit eurer Teamnummer (`01`, `02` oder `03`), der öffentlichen
IP des Domain Controllers, dem SHA256-Fingerprint der Workshop-CA und vier Passwörtern:
für `t01.hans`, `t01.anna`, das Bind-Konto `t01.bind` und das Übungskonto `t01.operator`.
Alle Beispiele zeigen Team 01; ersetzt `t01` und `Team01` durch eure Nummer.

Alle Befehle starten in `workshops/active-directory/lab` des Kurs-Repositories.

> **Hinweis:** Falls die Container einer vorherigen Übung noch laufen, stoppt diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details siehe
> [Troubleshooting](../../labs/assignments/TROUBLESHOOTING.md#container-name-konflikt).

1. `.env` anlegen und die IP eintragen. Die Datei `certs/workshop-ca.crt` kommt vom Trainer.

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

3. Fingerprint der CA mit dem Zettel vergleichen. Erst wenn er passt, geht es weiter:

   ```bash
   docker compose exec ldap-tools openssl x509 -in /certs/workshop-ca.crt -noout -fingerprint -sha256
   ```

4. Bind- und Übungspasswort im Werkzeugcontainer ablegen. Die Dateien landen in `secrets/`
   und bleiben außerhalb von Git:

   ```bash
   docker compose exec -it ldap-tools save-secret bind
   docker compose exec -it ldap-tools save-secret operator
   ```

Danach erreicht ihr Keycloak unter <http://localhost:8080> (`admin` / `admin`), das Portal
unter <http://localhost:5173> und die API unter <http://localhost:3001>. Der Realm `mustertech`
enthält Rollen, Gruppen und Clients, aber noch keinen LDAP-Provider und keine AD-Benutzer.

## Versuch 1: AD-Einträge lesen (0-15 Minuten)

Sagt vorher, wie der DN von Hans aussieht und welche Gruppen bei ihm direkt eingetragen sind.

**Bash:**

```bash
docker compose exec ldap-tools ldapsearch -LLL -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.bind@ad.mustertech.test" -y /secrets/bind.pw \
  -b "OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test" \
  "(sAMAccountName=t01.hans)" dn userPrincipalName objectGUID memberOf
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapsearch -LLL -x -H ldaps://dc01.ad.mustertech.test:636 `
  -D "t01.bind@ad.mustertech.test" -y /secrets/bind.pw `
  -b "OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test" `
  "(sAMAccountName=t01.hans)" dn userPrincipalName objectGUID memberOf
```

`objectGUID::` mit zwei Doppelpunkten ist Base64 für 16 Binärbytes. Der Werkzeugcontainer
wandelt den Wert in die Schreibweise um, die Keycloak später als `LDAP_ID` zeigt:

```bash
docker compose exec ldap-tools decode-guid "<Base64-Wert aus der Ausgabe>"
```

Wiederholt die Suche für `t01.anna` und tragt ein:

| Benutzer | DN | UPN | objectGUID (dekodiert) | Direkte Gruppen (`memberOf`) |
| -------- | -- | --- | ---------------------- | ---------------------------- |
| Hans     |    |     |                        |                              |
| Anna     |    |     |                        |                              |

Lest danach die Gruppe `Manager`:

```bash
docker compose exec ldap-tools ldapsearch -LLL -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.bind@ad.mustertech.test" -y /secrets/bind.pw \
  -b "OU=Groups,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test" "(cn=Manager)" member
```

Haltet fest: Warum steht `Manager` bei Anna nicht in `memberOf`, obwohl sie später Managerrechte
bekommen soll? Welche Kette führt von Anna zu `Manager`?

## Versuch 2: Keycloak über LDAPS verbinden (15-35 Minuten)

Öffnet in der Admin-Konsole den Realm `mustertech`, dann **User federation → Add Ldap providers**.
Sagt vor dem Speichern voraus, ob "Test connection" und "Test authentication" mit dem Bind-Konto
funktionieren und ob danach schon Benutzer in Keycloak sichtbar sind.

| Feld                    | Wert                                                              |
| ----------------------- | ----------------------------------------------------------------- |
| UI display name         | `ad-team01`                                                       |
| Vendor                  | Active Directory                                                  |
| Connection URL          | `ldaps://dc01.ad.mustertech.test:636`                             |
| Use Truststore SPI      | Always                                                            |
| Bind type               | simple                                                            |
| Bind DN                 | `t01.bind@ad.mustertech.test`                                     |
| Bind credentials        | Passwort von `t01.bind`                                           |
| Edit mode               | READ_ONLY                                                         |
| Users DN                | `OU=Users,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test`      |
| Username LDAP attribute | `userPrincipalName`                                               |
| RDN LDAP attribute      | `cn`                                                              |
| UUID LDAP attribute     | `objectGUID`                                                      |
| User object classes     | `person, organizationalPerson, user`                              |
| User LDAP filter        | siehe unten                                                       |
| Search scope            | Subtree                                                           |
| Import users            | On                                                                |
| Sync Registrations      | Off                                                               |

Der Filter beschränkt den Import auf die beiden Testbenutzer. Bind- und Übungskonto dürfen nie
im Portal landen:

```text
(|(sAMAccountName=t01.hans)(sAMAccountName=t01.anna))
```

Klickt **Test connection**, dann **Test authentication**, dann **Save**. Prüft unter **Mappers**,
welche Mapper Keycloak für den Vendor Active Directory angelegt hat, und notiert, was der
Mapper `MSAD account controls` laut seiner Beschreibung tut.

Klickt oben rechts **Action → Sync all users**. Öffnet **Users**: Wie heißt der Benutzername von
Hans in Keycloak, und was steht bei ihm unter **Attributes** in `LDAP_ID`? Vergleicht mit eurer Tabelle.

Meldet euch jetzt im **privaten Browserfenster** unter <http://localhost:5173> als
`t01.hans@ad.mustertech.test` mit dem Passwort vom Zettel an. Klickt im Portal
**Mein Profil** und **Meine Urlaubsanträge**. Sagt die beiden Statuscodes vorher voraus.

Haltet fest: Welche Rollen zeigt **Mein Profil**, und warum antwortet `/api/urlaubsantraege`
so, wie es antwortet, obwohl die Anmeldung gegen AD funktioniert hat?

## Versuch 3: Gruppen und verschachtelte Gruppen (35-55 Minuten)

Legt unter **User federation → ad-team01 → Mappers → Add mapper** den Gruppen-Mapper an:

| Feld                            | Wert                                                          |
| ------------------------------- | ------------------------------------------------------------- |
| Name                            | `ad-groups`                                                   |
| Mapper type                     | group-ldap-mapper                                             |
| LDAP Groups DN                  | `OU=Groups,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test` |
| Group Name LDAP Attribute       | `cn`                                                          |
| Group Object Classes            | `group`                                                       |
| Preserve Group Inheritance      | Off                                                           |
| Membership LDAP Attribute       | `member`                                                      |
| Membership Attribute Type       | DN                                                            |
| Membership User LDAP Attribute  | `cn`                                                          |
| Mode                            | READ_ONLY                                                     |
| User Groups Retrieve Strategy   | LOAD_GROUPS_BY_MEMBER_ATTRIBUTE                               |
| Groups Path                     | `/`                                                           |

Speichert, klickt beim Mapper **Action → Sync LDAP groups to Keycloak** und beim Provider
**Action → Sync all users**. Öffnet **Groups**: Die Gruppen `Mitarbeiter`, `Teamleitung` und
`Manager` gab es schon aus dem Realm-Import; die ersten beiden tragen die Rollen `mitarbeiter`
beziehungsweise `manager`. Prüft bei Anna unter **Groups** und **Role mapping** (mit geerbten Rollen),
was sie jetzt hat.

Meldet Anna im privaten Fenster an und klickt **Alle Anträge (Manager)**. Vorhersage, dann Ergebnis:

| Schritt                                      | Vorhersage | Ergebnis (HTTP-Status) |
| -------------------------------------------- | ---------- | ---------------------- |
| Anna, `/api/urlaubsantraege/alle`, direkt    |            |                        |
| Anna, `/api/urlaubsantraege/alle`, rekursiv  |            |                        |
| Hans, `/api/urlaubsantraege/alle`            |            |                        |
| ohne Token, `/api/urlaubsantraege/alle`      |            |                        |

Stellt danach im Mapper **User Groups Retrieve Strategy** auf
`LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY`, speichert, synchronisiert Gruppen und Benutzer
erneut. Meldet Anna ab und wieder an, damit ein neuer Token entsteht, und klickt erneut.

Den Fall ohne Token prüft ihr in der Shell:

**Bash:**

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3001/api/urlaubsantraege/alle
```

**PowerShell:**

```powershell
try { Invoke-WebRequest http://localhost:3001/api/urlaubsantraege/alle }
catch { $_.Exception.Response.StatusCode.value__ }
```

Notiert aus Annas Access Token (Portal, **Access Token anzeigen**, dann [jwt.io](https://jwt.io))
die Werte `iat`, `exp` und `realm_access.roles`. Wie lange ist der Token gültig?

## Versuch 4: Hans nach Moved verschieben (55-65 Minuten)

Notiert vorher drei Werte von Hans: seinen DN aus Versuch 1, seine dekodierte objectGUID und
seine Keycloak-Benutzer-ID (Admin-Konsole, **Users → Hans**, ID in der Adresszeile).
Sagt voraus, welcher der drei Werte sich durch das Verschieben ändert.

Verschiebt Hans mit dem Übungskonto. Die LDIF-Datei liegt für euer Team bereit:

**Bash:**

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/team01/01-hans-nach-moved.ldif
```

**PowerShell:**

```powershell
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 `
  -D "t01.operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/team01/01-hans-nach-moved.ldif
```

Sucht Hans jetzt zweimal mit dem Bind-Konto: einmal unter
`OU=Users,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test`, einmal unter der Team-OU.
Welche Suche findet ihn, und was zeigt `objectGUID`?

Meldet Hans im privaten Fenster an. Haltet genau fest, was passiert, und schaut in der
Admin-Konsole nach, ob sein Benutzer noch da ist, ob er aktiviert ist und was Keycloak
beim Anmeldeversuch protokolliert (`docker compose logs keycloak`).

Erweitert dann im Provider **Users DN** auf `OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test`.
Der Filter bleibt. Speichert, **Sync all users**, Hans erneut anmelden. Vergleicht die
Keycloak-Benutzer-ID und `LDAP_ID` mit euren Notizen.

| Wert                 | Vorher | Nachher | Gleich? |
| -------------------- | ------ | ------- | ------- |
| DN                   |        |         |         |
| objectGUID           |        |         |         |
| Keycloak-Benutzer-ID |        |         |         |

## Versuch 5: Rechte entziehen und Konto sperren (65-80 Minuten)

Meldet Anna an und kopiert ihren Access Token aus dem Portal in eine Datei `anna.jwt`
(nur der Token, ohne Zeilenumbruch). Notiert die Uhrzeit und `exp`.

Nehmt Anna aus `Teamleitung`:

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/team01/02-anna-aus-teamleitung.ldif
```

Testet den alten Token gegen die API, mehrmals bis nach `exp`:

**Bash:**

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $(cat anna.jwt)" \
  http://localhost:3001/api/urlaubsantraege/alle
```

**PowerShell:**

```powershell
$jwt = Get-Content anna.jwt -Raw
try { (Invoke-WebRequest http://localhost:3001/api/urlaubsantraege/alle -Headers @{ Authorization = "Bearer $jwt" }).StatusCode }
catch { $_.Exception.Response.StatusCode.value__ }
```

Synchronisiert Gruppen und Benutzer in Keycloak, meldet Anna ab und wieder an, klickt
**Alle Anträge (Manager)**. Tragt ein, wann welche Stelle die Änderung gesehen hat:

| Stelle                                | Zeitpunkt | Beobachtung |
| ------------------------------------- | --------- | ----------- |
| LDAP (`memberOf` von Anna)            |           |             |
| Keycloak (Groups von Anna nach Sync)  |           |             |
| Alter Token gegen API vor `exp`       |           |             |
| Alter Token gegen API nach `exp`      |           |             |
| Neuer Token gegen API                 |           |             |

Deaktiviert jetzt Hans. Lest vorher seinen aktuellen `userAccountControl`-Wert; die LDIF-Datei
setzt `66050` (Ausgangswert `66048` plus `ACCOUNTDISABLE` = 2). Hans liegt noch in `OU=Moved`:

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/team01/03-hans-deaktivieren.ldif
```

Lasst dabei ein Fenster mit angemeldetem Hans offen. Prüft nacheinander und notiert jeweils
Uhrzeit und Beobachtung:

1. Neuer Login als Hans in einem weiteren privaten Fenster.
2. Das offene Fenster: Seite neu laden, **Mein Profil** klicken.
3. Nach **Sync all users**: Ist Hans in der Admin-Konsole noch **Enabled**?
4. Ein vorher gesicherter Token von Hans gegen `/api/profile` bis `exp`.
5. **Sessions** in der Admin-Konsole: Existiert Hans' Sitzung noch?

## Versuch 6: Rücknahme und Auswertung (80-90 Minuten)

Nehmt alles in dieser Reihenfolge zurück, jeweils mit dem Übungskonto:

```bash
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/team01/04-hans-aktivieren.ldif
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/team01/05-anna-in-teamleitung.ldif
docker compose exec ldap-tools ldapmodify -x -H ldaps://dc01.ad.mustertech.test:636 \
  -D "t01.operator@ad.mustertech.test" -y /secrets/operator.pw -f /ldif/team01/06-hans-zurueck-nach-users.ldif
```

Setzt im Provider **Users DN** wieder auf `OU=Users,OU=Team01,...`. Entscheidet, ob die
Strategie rekursiv bleibt, und begründet das. Synchronisiert Gruppen und Benutzer, beendet
unter **Sessions** alle Sitzungen der beiden Benutzer.

Nachweis des Ausgangszustands: frischer Login als Hans und als Anna, dann
`/api/urlaubsantraege` für beide und `/api/urlaubsantraege/alle` für beide. Die Statuscodes
müssen denen aus Versuch 3 mit rekursiver Strategie entsprechen.

Zum Abschluss beantwortet ihr für die Auswertung:

1. Wie findet Keycloak einen AD-Benutzer, und wessen Passwort prüft "Test authentication"?
2. Warum reicht `member` allein nicht für Annas Managerrechte, und was ändert die rekursive Strategie?
3. Was bleibt beim OU-Wechsel stabil, und wovon hängt ab, ob Keycloak den Benutzer weiter kennt?
4. Welche Stelle bemerkt Rechteentzug und Deaktivierung zuerst, welche zuletzt, und warum?

Lasst den Stack laufen, bis der Trainer die Ergebnisse gesehen hat. Danach:

```bash
docker compose down -v
```
