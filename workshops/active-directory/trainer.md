# Traineranleitung: Active Directory auf GCP

## Vorbereitung

Jede Person bekommt einen eigenen Domain Controller. Die Umgebungen entstehen am Vortag mit dem
Flotten-Skript, werden über Nacht gestoppt und am Kursmorgen gestartet. Vor der Bereitstellung
müssen vorliegen: Projekt-ID mit aktivierter Abrechnung, Compute Engine API und IAP API, Region
und Zone, die öffentliche Ausgangs-IP des Schulungsraums als CIDR (höchstens `/24`), der eigene
Principal für den IAP-Tunnel und ein öffentlicher SSH-Schlüssel (`~/.ssh/id_ed25519.pub`).
`New-Workshop.ps1` bricht bei fehlenden APIs, fehlender Abrechnung, erschöpftem Netz-Quota oder zu
weiten Quellnetzen ab und aktiviert nichts von selbst. Fünf Umgebungen brauchen fünf VPCs; in einem
neuen Projekt belegt das `default`-Netz eines der fünf erlaubten Netze und muss vorher weg:

```powershell
gcloud compute firewall-rules list --project <projekt> --filter "network~'/default$'" --format "value(name)" |
  ForEach-Object { gcloud compute firewall-rules delete $_ --project <projekt> --quiet }
gcloud compute networks delete default --project <projekt> --quiet
```

Je Person gehen an sie: IP des eigenen DC, die Datei `workshop-ca.crt`, der CA-Fingerprint und die
Passwörter für `hans`, `anna`, `bind` und `operator`. `Invoke-WorkshopFleet.ps1 -Action Packages`
zeigt alle Werte je Umgebung; die Dateien liegen unter `.run/<präfix>/`.

## Bereitstellung

Alle Befehle aus `workshops/active-directory/scripts` in PowerShell 7. Beispiel für fünf Personen:

```powershell
gcloud auth login
./Invoke-WorkshopFleet.ps1 -Action Deploy -Count 5 -ProjectId <projekt> -Zone europe-west3-a `
  -LdapsSourceRanges 203.0.113.0/24 -TrainerPrincipal 'user:trainer@example.org' `
  -ExpiresAt (Get-Date).AddHours(36) -CertificateValidUntil (Get-Date).AddDays(7) -PlanOnly
./Invoke-WorkshopFleet.ps1 -Action Deploy -Count 5 -ProjectId <projekt> -Zone europe-west3-a `
  -LdapsSourceRanges 203.0.113.0/24 -TrainerPrincipal 'user:trainer@example.org' `
  -ExpiresAt (Get-Date).AddHours(36) -CertificateValidUntil (Get-Date).AddDays(7)
```

Deploy legt die Umgebungen `kcad1` bis `kcad5` nacheinander mit `New-Workshop.ps1 -TrainerSsh` an
(je rund sechs Minuten bis Windows bereit ist) und führt danach die Gastseite aller Umgebungen
parallel über `lib/Invoke-GuestSetup.ps1` aus: Neustart für das SSH-Startskript, die drei Phasen
von `Initialize-Domain.ps1` mit lokal erzeugten Passwörtern, `Protect-Workshop.ps1`,
`Initialize-Workshop.ps1`, Abholen von CA, Zusammenfassung und Geheimnissen, Gastprüfung. Zum Schluss
läuft die Trainerprüfung je Umgebung. Logs liegen unter `.run/<präfix>/setup.log`; ein erneuter
Aufruf setzt fehlgeschlagene Umgebungen dort fort, wo der Gast steht.

Danach:

```powershell
./Invoke-WorkshopFleet.ps1 -Action Packages          # Werte je Person
./Invoke-WorkshopFleet.ps1 -Action Stop              # am Vorabend
./Invoke-WorkshopFleet.ps1 -Action Start             # am Kursmorgen, wartet auf LDAPS und prueft
./Invoke-WorkshopFleet.ps1 -Action Status            # Instanzzustand und IPs
```

Das Manifest jeder Umgebung (`.run/<präfix>/manifest.json`) enthält Projekt, Zone, Ressourcen mit
selfLinks, IPs, Image-Version und die IAP-Bindung; es ist Grundlage für Test und Abbau. Daneben liegen
`workshop-ca.crt`, `workshop-ad.json`, `secrets/workshop.json` (die vier Passwörter),
`secrets/domain-admin.json` (Administrator und DSRM) und `secrets/wsadmin.json`.

### Einzelne Umgebung von Hand

Die Einzelskripte funktionieren weiterhin, jeweils mit `-Prefix`:
`New-Workshop.ps1 -Prefix kcad1 ...`, `Protect-Workshop.ps1 -Prefix kcad1`, `Test-Workshop.ps1 -Mode
Trainer -Prefix kcad1`, `Remove-Workshop.ps1 -Prefix kcad1`. Für den Gast gibt es zwei Wege:

**RDP über IAP** (ohne `-TrainerSsh`):

```powershell
gcloud compute start-iap-tunnel kcad1-dc01 3389 --local-host-port=localhost:33389 --zone=europe-west3-a --project=<projekt>
```

Mit dem RDP-Client auf `localhost:33389` als `wsadmin` (Passwort in `.run/kcad1/secrets/wsadmin.json`).
Die Skripte kommen per Zwischenablage oder direkt aus dem öffentlichen Repository in den Gast:

```powershell
$base = 'https://raw.githubusercontent.com/it-erben/training-keycloak/main/workshops/active-directory/scripts'
New-Item -ItemType Directory -Path C:\Workshop\scripts -Force | Out-Null
foreach ($f in 'Initialize-Domain.ps1', 'Initialize-Workshop.ps1', 'Reset-Baseline.ps1', 'Test-Workshop.ps1') {
  Invoke-WebRequest "$base/$f" -OutFile "C:\Workshop\scripts\$f"
}
```

`Initialize-Domain.ps1` läuft dreimal, jeweils in einer PowerShell als Administrator:

1. Phase 1 formatiert die 20-GiB-Datendisk als `D:` und benennt den Rechner in `dc01` um. Neustart.
2. Phase 2 installiert AD DS und DNS, fragt das Passwort für das eingebaute Konto `Administrator`
   und das DSRM-Passwort ab und promotet den Forest `ad.mustertech.test`. Neustart. Das Konto
   `wsadmin` existiert danach nicht mehr; die Anmeldung erfolgt als `MUSTERTECH\Administrator`.
3. Phase 3 setzt den DNS-Forwarder auf den Metadaten-Resolver `169.254.169.254`, die Zeitquelle auf
   `metadata.google.internal`, prüft die LDAPS-Firewallregel und die Erreichbarkeit von
   `kms.windows.googlecloud.com`.

Erst wenn die Anmeldung als `MUSTERTECH\Administrator` funktioniert, vom Trainerrechner aus
`./Protect-Workshop.ps1 -Prefix kcad1` ausführen. Es setzt `disable-account-manager=true`; ein
späteres `reset-windows-password` kann dann keine Domänenkonten mehr anlegen oder ändern.

`Initialize-Workshop.ps1 -CertificateValidUntil (Get-Date).AddDays(7)` im Gast erzeugt die
Workshop-CA, das LDAPS-Zertifikat mit `dc01.ad.mustertech.test` im SAN, die OU `Workshop` mit
`Users`, `Moved`, `Groups` und `ServiceAccounts`, Gruppen, Konten, Passwörter und die Delegation per
`dsacls`. Wiederholte Aufrufe ergänzen nur Fehlendes; `-ResetPasswords` setzt alle Passwörter neu.
Anschließend vom DC holen: `C:\Workshop\out\workshop-ca.crt`, `workshop-ad.json` und
`C:\Workshop\secrets\workshop.json` nach `.run/kcad1/`.

**SSH über IAP** (mit `-TrainerSsh`): `New-Workshop.ps1` legt zusätzlich die Firewallregel
`kcad1-allow-iap-ssh` (TCP 22 nur aus dem IAP-Bereich) an, erweitert die IAP-Bedingung auf 3389 und 22
und hinterlegt das Startskript `scripts/lib/Enable-TrainerSsh.ps1` samt öffentlichem Schlüssel in den
Instanz-Metadaten. Geheimnisse liegen dabei nicht in den Metadaten.

```powershell
gcloud compute start-iap-tunnel kcad1-dc01 22 --local-host-port=localhost:2222 --zone=europe-west3-a --project=<projekt>
ssh -p 2222 wsadmin@127.0.0.1                  # vor der Promotion
ssh -p 2222 Administrator@127.0.0.1            # nach der Promotion, Domaenen-Administrator
scp -O -P 2222 scripts/Initialize-Domain.ps1 wsadmin@127.0.0.1:C:/Workshop/scripts/
```

`Initialize-Domain.ps1 -Unattended` liest die beiden Passwörter (Administrator, DSRM) als je eine Zeile
von stdin; `lib/Invoke-GuestSetup.ps1 -Prefix kcad1 -CertificateValidUntil <datum>` fasst den gesamten
Gastweg für eine Umgebung zusammen.

Prüfung: `Test-Workshop.ps1 -Mode Guest` auf dem DC, lokal `./Test-Workshop.ps1 -Mode Trainer -Prefix
kcad1 -IncludeIap`. Beide schreiben einen Bericht und enden mit Exit-Code 1 bei einem Fehlschlag. Die
Trainerprüfung belegt unter anderem, dass TLS mit falschem Namen und ohne CA scheitert, dass Port 3389
und 22 direkt geschlossen sind und dass das Übungskonto an Dienstkonten mit `insufficientAccessRights`
abgewiesen wird.

## Musterlösung je Aufgabe

Die Trainerlösung `solution/apply-solution.sh` erzeugt denselben Provider, den die Teilnehmer in
Aufgabe 2 und 3 anlegen. Sie eignet sich für die eigene Vorführung und für ein Team, das den Anschluss verliert.

### Aufgabe 1: Einträge lesen

Erwartete Werte:

- Hans: `CN=Hans Mueller,OU=Users,OU=Workshop,DC=ad,DC=mustertech,DC=test`,
  UPN `hans@ad.mustertech.test`, `memberOf` nur `CN=Mitarbeiter,OU=Groups,...`.
- Anna: `memberOf` enthält `Mitarbeiter` und `Teamleitung`, nicht `Manager`.
- `Manager` hat genau ein `member`: den DN von `Teamleitung`.

`memberOf` ist ein berechnetes Rücklink-Attribut und zeigt nur direkte Mitgliedschaften.
Die Kette Anna → Teamleitung → Manager ist im Verzeichnis vorhanden, aber nicht an Annas Eintrag ablesbar.
`decode-guid` liefert dieselbe Schreibweise wie `LDAP_ID` in Keycloak; die ersten drei Blöcke stehen
in AD in umgekehrter Byte-Reihenfolge, deshalb stimmt ein naiver Hex-Dump nicht überein.

In Windows den Wert zeigen: AD Users and Computers, Ansicht "Erweiterte Features", Eintrag
Hans, Reiter "Attribut-Editor", `objectGUID` und `distinguishedName`.

### Aufgabe 2: LDAPS-Anbindung

"Test connection" prüft DNS, TCP, TLS-Kette und Hostnamen; "Test authentication" bindet mit dem
Bind-Konto, nicht mit Hans. Nach "Sync all users" heißt Hans `hans@ad.mustertech.test`,
weil `userPrincipalName` als Username-Attribut gewählt ist. Erst der Login im privaten Fenster
prüft Hans' Passwort gegen AD.

`/api/profile` liefert 200, `/api/urlaubsantraege` liefert 403: Hans hat noch keine Gruppe und
damit keine Rolle `mitarbeiter`. Der Access Token trägt `portal-api` in `aud`; die Portal-API in
diesem Repository prüft Signatur und Issuer, den Audience-Claim zeigt sie im Token, wertet ihn
aber nicht aus. Das ist eine Eigenschaft von `labs/assignments/services/portal-api`, nicht des Workshops.

### Aufgabe 3: Direkte und rekursive Gruppen

Mit `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE` sucht Keycloak Gruppen, deren `member` Annas DN enthält:
`Mitarbeiter` und `Teamleitung`. `Manager` enthält nur den DN von `Teamleitung`, also fehlt die
Rolle `manager`, und `/api/urlaubsantraege/alle` antwortet 403. Mit
`LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY` folgt Keycloak der Kette und Anna erhält `Manager`.
Nach Gruppen-Sync, Benutzer-Sync und neuem Login antwortet die API 200. Hans bleibt bei 403,
ohne Token 401. Preserve Group Inheritance bleibt aus; sonst entstünde `Manager/Teamleitung` als
Untergruppe und Anna erbte `manager` über die Keycloak-Hierarchie, ohne dass die Strategie eine Rolle spielt.

Access Tokens gelten im Realm 120 Sekunden (`exp - iat`).

### Aufgabe 4: OU-Wechsel

Der DN wechselt auf `CN=Hans Mueller,OU=Moved,...`, `objectGUID` bleibt. Die Suche unter
`OU=Users` findet ihn nicht mehr, die Suche unter `OU=Workshop` schon. Was Keycloak beim Login
mit dem bereits importierten, jetzt außerhalb der Suchbasis liegenden Benutzer tut, gehört zu
den Ergebnissen des Probelaufs; die Anleitung verspricht deshalb keine stabile Keycloak-ID.
Beobachtet mit Keycloak 26.5.7: Der Login scheitert mit "Invalid user credentials", Keycloak löscht den
lokalen Import, und nach Erweiterung der Users DN entsteht beim Sync ein neuer Keycloak-Benutzer mit
neuer ID und gleicher `LDAP_ID`. Details im Abschnitt "Beobachtungen aus dem Probelauf".

### Aufgabe 5: Rechteentzug und Deaktivierung

Ein bereits ausgestellter JWT ändert sich nicht. Die API prüft nur Signatur und Issuer und
akzeptiert den alten Token bis `exp`. Keycloak zeigt die fehlende Gruppe erst nach Sync;
ein neuer Token enthält `manager` dann nicht mehr. Bei der Deaktivierung scheitert ein frischer
Login ohne SSO am Bind gegen AD (Fehlercode 533 im LDAP-Diagnosetext, "account disabled").
Der MSAD-Mapper setzt beim Sync `enabled` anhand von `userAccountControl`. Bis dahin laufen
Sitzung und Refresh weiter; erst nach dem Sync lehnt Keycloak den Refresh mit "User disabled" ab,
bestehende Sitzungen bleiben trotzdem in der Sitzungsliste. Zeitstempel im Abschnitt
"Beobachtungen aus dem Probelauf".

### Aufgabe 6: Rücknahme

Reihenfolge der LDIF-Dateien 04, 05, 06: erst aktivieren und Anna wieder in `Teamleitung`, dann Hans
zurück nach `Users`, weil die LDIF-Dateien 04 und 06 seinen DN unter `OU=Moved` erwarten. Users DN
zurück auf `OU=Users`, Sync, Sitzungen beenden, frische Logins. Ergebnis wie in Aufgabe 3 mit rekursiver
Strategie: Hans 200 auf `/api/urlaubsantraege` und 403 auf `/alle`, Anna 200 auf beiden.

## Beobachtungen aus dem Probelauf

Erster Probelauf am 15.09.2026 mit einem gemeinsamen DC und Team-OUs (`t01.hans`, `OU=Team01`);
die Konten heißen seit der Umstellung auf einen DC je Person `hans`, `anna`, `bind` und `operator`
unter `OU=Workshop`. Das Verhalten von Keycloak ist davon unabhängig. Projekt `keycloak-qards`, Zone `europe-west3-a`, Image
`windows-server-2022-dc-v20260909`, `e2-standard-2`, gcloud 565.0.0, Keycloak 26.5.7, PostgreSQL 18.
Gastzugang über SSH per IAP, Bereitstellung, Promotion und Vorbereitung dauerten zusammen rund 75 Minuten
einschließlich dreier Neustarts. Trainerprüfung 25 von 25 PASS (mit IAP-Tunnel), Gastprüfung 16 von 16 PASS.

### Aufgabe 1

`memberOf` von Hans enthält nur `Mitarbeiter`, das von Anna `Teamleitung` und `Mitarbeiter`; `Manager`
hat als einziges `member` den DN von `Teamleitung`. `objectGUID:: S6nBAdsmPkONmfzgwrwP2Q==` ergibt mit
`decode-guid` den Wert `01c1a94b-26db-433e-8d99-fce0c2bc0fd9`, identisch mit `LDAP_ID` in Keycloak.

### Aufgabe 2 und 3

Provider und Mapper aus der Trainerlösung verbinden sich über LDAPS mit der Workshop-CA; "Sync all users"
meldet beim zweiten Lauf `0 imported users, 2 updated users`. Hans heißt in Keycloak
`t01.hans@ad.mustertech.test`. Ein frischer Login (Passwort gegen AD) liefert einen Token mit
`exp - iat = 120`. Mit direkter Strategie hat Anna die Keycloak-Gruppen `Mitarbeiter` und `Teamleitung`,
`/api/urlaubsantraege/alle` antwortet 403. Nach Umstellung auf `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY`,
Gruppen-Sync und Benutzer-Sync kommt `Manager` hinzu; ein neuer Token enthält `manager`, die API antwortet 200.
Hans bleibt bei 403, ohne Token 401.

### Aufgabe 4

Nach dem `modrdn` findet die Suche unter `OU=Users` nichts (Exit 0, null Einträge), die Suche unter der
Team-OU liefert den neuen DN mit unveränderter `objectGUID`. Ein Login als Hans mit Users DN `OU=Users`
scheitert mit "Invalid user credentials"; das Keycloak-Ereignis lautet `LOGIN_ERROR` mit
`error=user_not_found`, und Keycloak entfernt dabei den lokalen Import: Hans fehlt danach in **Users**.
Nach Erweiterung der Users DN auf die Team-OU und "Sync all users" ist Hans wieder importiert, mit
**neuer Keycloak-ID** (`3bb7e75d…` wurde `23a07b14…`), gleicher `LDAP_ID` und `LDAP_ENTRY_DN` unter
`OU=Moved`. Der `sub` im Token ändert sich damit ebenfalls; Anwendungen, die Benutzer an `sub` binden,
verlieren die Zuordnung. Die stabile Identität ist `objectGUID`.

### Aufgabe 5

Anna aus `Teamleitung` entfernt um 17:47:30 UTC, Token `exp` 17:49:30. Der alte Token liefert vor und
nach dem Keycloak-Sync 200 und erst nach `exp` 401: Die API prüft nur Signatur und Ablauf. Nach dem Sync
hat Anna nur noch `Mitarbeiter`; ein neuer Token enthält kein `manager`, die API antwortet 403. Ein Refresh
mit dem noch gültigen Refresh-Token funktioniert und liefert einen Token ohne `manager`, weil Keycloak die
Rollen beim Refresh neu berechnet.

Hans deaktiviert (`userAccountControl` 66050) um 17:47:42 UTC, Hans lag dabei in `OU=Moved`:

| Stelle                                  | Beobachtung                                                       |
| --------------------------------------- | ----------------------------------------------------------------- |
| Frischer Login ohne SSO                 | "Invalid user credentials", Ereignis `invalid_user_credentials`   |
| Alter Access Token gegen `/api/profile` | 200 bis `exp`, danach 401                                         |
| Refresh vor dem Sync                    | erfolgreich, neuer Token wird ausgestellt                         |
| **Enabled** in Keycloak vor dem Sync    | `true`                                                            |
| **Enabled** nach "Sync all users"       | `false` (MSAD-Mapper liest `userAccountControl`)                  |
| Refresh nach dem Sync                   | `invalid_grant`, "User disabled"                                  |
| Sitzungen nach dem Sync                 | beide Sitzungen bestehen weiter; der Sync beendet keine Sitzungen |

### Aufgabe 6

LDIF 04, 05, 06, Users DN zurück auf `OU=Users`, Sync und "Beende alle Sitzungen": Hans ist aktiviert
(`userAccountControl` 66048), die drei Gruppen entsprechen der Baseline. Frische Logins liefern Hans
200 auf `/api/urlaubsantraege` und 403 auf `/alle`, Anna 200 auf beiden. Hans behält die neue Keycloak-ID
aus Aufgabe 4. `Reset-Baseline.ps1` ändert danach nichts mehr.

### Zweiter Probelauf: ein DC je Person

Am 15.09.2026 abends mit zwei Umgebungen (`kcad1`, `kcad2`) über `Invoke-WorkshopFleet.ps1 -Action Deploy
-Count 2`: Anlegen je rund sechs Minuten, danach beide Gastseiten parallel über SSH per IAP in rund
15 Minuten bis zur Gastprüfung (je 10 PASS), Trainerprüfung je 14 PASS und 1 SKIP (IAP-Tunnel ohne
Schalter). `-Action Stop` setzte beide VMs in rund eine Minute auf TERMINATED, `-Action Start` brachte
LDAPS in rund 90 Sekunden zurück; externe Adressen blieben erhalten, Trainerprüfung danach wieder 14 PASS.

Der vollständige Teilnehmerlauf nach `aufgabe.md` gegen `kcad1` von diesem Laptop (Stack frisch mit
`docker compose down -v` und `up -d --build`, Bash- und PowerShell-Befehle, Provider und Mapper mit den
Werten aus den Tabellen über die Admin-API) lieferte dieselben Ergebnisse wie der erste Probelauf:
Aufgabe 3 direkt 403 und rekursiv 200, Hans 403, ohne Token 401; Aufgabe 4 `user_not_found`, gelöschter
Import, neue Keycloak-ID mit gleicher `LDAP_ID`; Aufgabe 5 alter Token 200 bis `exp`, Refresh vor dem
Sync erfolgreich, nach dem Sync "User disabled"; Aufgabe 6 Hans 200 und 403, Anna 200 und 200, Hans
zurück in `OU=Users` mit `userAccountControl` 66048. `Reset-Baseline.ps1` stellte zwischen den Läufen den
Ausgangszustand her. Der Authorization Code Flow mit PKCE lieferte für Hans einen Token mit `portal-api`
in `aud` und die API-Codes 200, 200, 403.

Ein Detail für eigene Skripte: Die erzeugten Passwörter enthalten Zeichen wie `%`. Wer Passwörter per
`curl -d` an den Token-Endpunkt schickt, braucht `--data-urlencode`; Browserformulare, `save-secret`
und `Invoke-RestMethod -Body @{...}` kodieren selbst.

### Anmeldung, Delegation und Netz

Der Authorization Code Flow mit PKCE (S256) wurde vom Portal bis zur Keycloak-Anmeldeseite im Browser und
für den Code-Tausch per HTTP-Skript geprüft: Token mit `portal-api` in `aud`, API 200, 200, 403 für Hans.
Das Bind-Konto scheitert beim Schreiben mit LDAP-Fehler 50, das Übungskonto an fremden Objekten ebenso;
Änderungen an den Testobjekten und Gruppen der Workshop-OU gelingen. Die effektive Firewall erlaubt 636 nur aus der gemeldeten
Quell-IP, 3389 und 22 nur aus dem IAP-Bereich; direkte Verbindungen auf 3389 und 22 scheitern. TLS mit
falschem Hostnamen oder ohne die Workshop-CA wird abgelehnt.

## Diagnoseleiter

Bei Verbindungsfehlern in dieser Reihenfolge, jeweils aus dem Werkzeugcontainer:

1. DNS: `getent hosts dc01.ad.mustertech.test` muss die externe IP aus `.env` liefern.
   Der Eintrag kommt aus `extra_hosts`; ein Eintrag nur auf dem Host reicht nicht.
2. TCP: `nc -zv dc01.ad.mustertech.test 636` oder `openssl s_client -connect ...:636`.
   Scheitert das, fehlt die Ausgangs-IP des Teams in der Firewallregel (`kcad-allow-ldaps`).
3. TLS muss `Verification: OK` melden, sonst ist die CA-Datei falsch oder das Zertifikat abgelaufen:

   ```bash
   openssl s_client -connect dc01.ad.mustertech.test:636 -servername dc01.ad.mustertech.test \
     -CAfile /certs/workshop-ca.crt -verify_hostname dc01.ad.mustertech.test -verify_return_error -brief
   ```

4. Bind: `ldapwhoami -x -H ldaps://... -D bind@ad.mustertech.test -y /secrets/bind.pw`.
   Fehler 49 mit `data 52e` ist ein falsches Passwort, `data 533` ein deaktiviertes Konto.
5. Suche: Basis, Scope und Filter einzeln prüfen. Eine erfolgreiche Suche mit null Treffern hat Exit 0.

Fehlt ein Benutzer in Keycloak: Users DN, Search scope und User LDAP filter prüfen, dann "Sync all users".
Fehlt ein Recht: Strategie des Group-Mappers, Gruppen-Sync, Rollen der Keycloak-Gruppe, Cache und
Ausstellungszeitpunkt des Tokens. Kein Fehler wird durch Abschalten der Zertifikatsprüfung oder
eine weitere Firewallregel gelöst.

## Rücknahme und Reset

Eine Umgebung auf den Ausgangszustand setzen, auf dem DC als Domänen-Administrator:

```powershell
C:\Workshop\scripts\Reset-Baseline.ps1
```

Das Skript verschiebt Hans und Anna zurück nach `Users`, aktiviert beide, stellt die drei
Mitgliedschaften her und entfernt fremde Mitglieder. Passwörter und Delegation bleiben. In Keycloak
danach `apply-solution.sh users-dn users`, `sync` und `logout-sessions` oder die entsprechenden
Klicks in der Admin-Konsole.

## Ersatz mit OpenLDAP

Ohne GCP läuft die Einheit mit Lab 07c und dem [Begleitmaterial](../ldap-ad/README.md).
Aufgabe 1, 3 (Gruppenänderung per LDIF), 5 (Rechteentzug) und 6 laufen dort gleichwertig,
mit `entryUUID` statt `objectGUID` und `groupOfNames` statt `group`. Aufgabe 2 entfällt bis auf
den Provider aus Lab 07c ohne TLS. Aufgabe 4 lässt sich mit `ldapmodrdn` nachstellen; die
AD-spezifischen Teile (MSAD-Mapper, `userAccountControl`, Zertifikatskette gegen Windows)
werden anhand des Abschnitts "Beobachtungen aus dem Probelauf" besprochen und als Aufzeichnung genannt.

## Abbau

Zeitpunkt mit der Kursleitung abstimmen; die Umgebungen bleiben bis zum Ende der Auswertung stehen.

```powershell
./Invoke-WorkshopFleet.ps1 -Action Remove -PlanOnly
./Invoke-WorkshopFleet.ps1 -Action Remove
./Remove-Workshop.ps1 -Prefix kcad1 -Local   # einzeln, zusaetzlich den lokalen Compose-Stack entfernen
```

Der Abbau prüft je Umgebung Projektnummer, selfLink und Labels jeder Ressource, entfernt zuerst die
IAP-Bindung, dann Instanz, Datendisk, Bootdisk, Adressen, Firewallregeln, Subnetz und VPC.
Danach mit `--filter="name~'^kcad-'"` in `gcloud compute instances list`, `disks list`,
`addresses list`, `firewall-rules list` und `networks list` bestätigen, dass nichts übrig ist.
Das Projekt, die aktivierten APIs und fremde IAM-Bindungen bleiben erhalten.
