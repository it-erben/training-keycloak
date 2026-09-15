# Traineranleitung: Active Directory auf GCP

## Vorbereitung

Die Umgebung entsteht am Vortag, der vollständige Probelauf gehört dazu. Vor der Bereitstellung
müssen vorliegen: Projekt-ID mit aktivierter Abrechnung, Compute Engine API und IAP API, Region
und Zone, die öffentlichen Ausgangs-IPs der Schulungsräume oder Gruppen als CIDR (höchstens `/24`),
der eigene Principal für den IAP-Tunnel und der Abbauzeitpunkt (höchstens 48 Stunden nach dem Start).
`New-Workshop.ps1` bricht bei fehlenden APIs, fehlender Abrechnung oder zu weiten Quellnetzen ab
und aktiviert nichts von selbst.

Je Team entsteht ein Zettel: Teamnummer, externe IP des DC, CA-Fingerprint, Passwörter für
`t<NN>.hans`, `t<NN>.anna`, `t<NN>.bind` und `t<NN>.operator`. Die Werte stammen aus
`C:\Workshop\out\workshop-ad.json` und `C:\Workshop\secrets\team<NN>.json` auf dem DC.
Das CA-Zertifikat `workshop-ca.crt` wird als Datei verteilt, etwa über den Kurschat.

## Bereitstellung

Alle Befehle aus `workshops/active-directory/scripts` in PowerShell 7. Beispielwerte:

```powershell
gcloud auth login
./New-Workshop.ps1 -ProjectId <projekt> -Region europe-west3 -Zone europe-west3-a `
  -LdapsSourceRanges @('203.0.113.0/24') -TrainerPrincipal 'user:trainer@example.org' `
  -ExpiresAt (Get-Date).AddHours(36) -PlanOnly
./New-Workshop.ps1 -ProjectId <projekt> -Region europe-west3 -Zone europe-west3-a `
  -LdapsSourceRanges @('203.0.113.0/24') -TrainerPrincipal 'user:trainer@example.org' `
  -ExpiresAt (Get-Date).AddHours(36)
```

Das Skript wartet, bis Windows sein erstes Setup gemeldet hat, legt das lokale Konto `wsadmin`
an und schreibt dessen Passwort nach `.run/secrets/wsadmin.json`. Das Manifest `.run/manifest.json`
enthält Projekt, Zone, Ressourcen mit selfLinks, IPs, Image-Version und die IAP-Bindung; es
ist Grundlage für Test und Abbau. Ein abgebrochener Lauf lässt sich mit demselben Aufruf
fortsetzen: vorhandene Ressourcen mit passender `run-id` werden übernommen, fremde führen zum Abbruch.

RDP läuft ausschließlich über IAP:

```powershell
gcloud compute start-iap-tunnel kcad-dc01 3389 --local-host-port=localhost:33389 --zone=europe-west3-a --project=<projekt>
```

Danach mit dem RDP-Client auf `localhost:33389` als `wsadmin` verbinden. Die Skripte kommen per
Zwischenablage oder direkt aus dem öffentlichen Repository in den Gast:

```powershell
$base = 'https://raw.githubusercontent.com/it-erben/training-keycloak/main/workshops/active-directory/scripts'
New-Item -ItemType Directory -Path C:\Workshop\scripts -Force | Out-Null
foreach ($f in 'Initialize-Domain.ps1', 'Initialize-Workshop.ps1', 'Reset-Team.ps1', 'Test-Workshop.ps1') {
  Invoke-WebRequest "$base/$f" -OutFile "C:\Workshop\scripts\$f"
}
```

### Ohne RDP: SSH über IAP

Mit `-TrainerSsh` legt `New-Workshop.ps1` zusätzlich die Firewallregel `kcad-allow-iap-ssh` (TCP 22 nur aus
dem IAP-Bereich) an, erweitert die IAP-Bedingung auf 3389 und 22 und hinterlegt das Startskript
`scripts/lib/Enable-TrainerSsh.ps1` samt dem öffentlichen Schlüssel aus `~/.ssh/id_ed25519.pub` in den
Instanz-Metadaten. Das Startskript installiert den Windows-OpenSSH-Server und wirkt nach dem nächsten
Neustart der VM (`gcloud compute instances reset`). Geheimnisse liegen dabei nicht in den Metadaten.

```powershell
gcloud compute start-iap-tunnel kcad-dc01 22 --local-host-port=localhost:2222 --zone=europe-west3-a --project=<projekt>
ssh -p 2222 wsadmin@127.0.0.1                  # vor der Promotion
ssh -p 2222 Administrator@127.0.0.1            # nach der Promotion, Domaenen-Administrator
scp -O -P 2222 scripts/Initialize-Domain.ps1 wsadmin@127.0.0.1:C:/Workshop/scripts/
```

`Initialize-Domain.ps1 -Unattended` liest die beiden Passwörter (Administrator, DSRM) als je eine Zeile
von stdin:

```powershell
Get-Content pw.txt | ssh -p 2222 wsadmin@127.0.0.1 "powershell -ExecutionPolicy Bypass -File C:\Workshop\scripts\Initialize-Domain.ps1 -Unattended"
```

Der Probelauf lief vollständig über diesen Weg; das RDP-Verfahren bleibt der Standard für Trainer mit RDP-Client.

`Initialize-Domain.ps1` läuft dreimal, jeweils in einer PowerShell als Administrator:

1. Phase 1 formatiert die 20-GiB-Datendisk als `D:` und benennt den Rechner in `dc01` um. Neustart.
2. Phase 2 installiert AD DS und DNS, fragt das Passwort für das eingebaute Konto `Administrator`
   und das DSRM-Passwort ab und promotet den Forest `ad.mustertech.test`. Neustart. Das Konto
   `wsadmin` existiert danach nicht mehr; die Anmeldung erfolgt als `MUSTERTECH\Administrator`.
3. Phase 3 setzt den DNS-Forwarder auf den Metadaten-Resolver `169.254.169.254`, die Zeitquelle auf
   `metadata.google.internal`, prüft die LDAPS-Firewallregel und die Erreichbarkeit von
   `kms.windows.googlecloud.com`.

Erst wenn die Anmeldung als `MUSTERTECH\Administrator` über RDP funktioniert, vom Trainerrechner
aus `./Protect-Workshop.ps1` ausführen. Es setzt `disable-account-manager=true`; ein späteres
`reset-windows-password` kann dann keine Domänenkonten mehr anlegen oder ändern.

`Initialize-Workshop.ps1 -CertificateValidUntil (Get-Date).AddDays(3)` im Gast erzeugt die
Workshop-CA, das LDAPS-Zertifikat mit `dc01.ad.mustertech.test` im SAN, die OU-Struktur, Gruppen,
Konten, Passwörter und die Delegation per `dsacls`. Wiederholte Aufrufe ergänzen nur Fehlendes;
`-ResetPasswords` setzt alle Passwörter neu. Anschließend vom DC holen: `C:\Workshop\out\workshop-ca.crt`
nach `lab/certs/`, `workshop-ad.json` und die `team<NN>.json` nach `.run/secrets/`.

Prüfung: `Test-Workshop.ps1 -Mode Guest` auf dem DC, dann lokal
`./Test-Workshop.ps1 -Mode Trainer -IncludeIap` mit laufendem Stack aus `lab/`. Beide schreiben
einen Bericht nach `.run/` und enden mit Exit-Code 1 bei einem Fehlschlag. Die Trainerprüfung
belegt unter anderem, dass TLS mit falschem Namen und ohne CA scheitert, dass Port 3389 direkt
geschlossen ist und dass das Übungskonto beim Nachbarteam mit `insufficientAccessRights` abgewiesen wird.

## Musterlösung je Versuch

Die Trainerlösung `solution/apply-solution.sh` erzeugt denselben Provider, den die Teilnehmer in
Versuch 2 und 3 anlegen. Sie eignet sich für die eigene Vorführung und für ein Team, das den Anschluss verliert.

### Versuch 1: Einträge lesen

Erwartete Werte für Team 01:

- Hans: `CN=Hans Mueller,OU=Users,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test`,
  UPN `t01.hans@ad.mustertech.test`, `memberOf` nur `CN=Mitarbeiter,OU=Groups,...`.
- Anna: `memberOf` enthält `Mitarbeiter` und `Teamleitung`, nicht `Manager`.
- `Manager` hat genau ein `member`: den DN von `Teamleitung`.

`memberOf` ist ein berechnetes Rücklink-Attribut und zeigt nur direkte Mitgliedschaften.
Die Kette Anna → Teamleitung → Manager ist im Verzeichnis vorhanden, aber nicht an Annas Eintrag ablesbar.
`decode-guid` liefert dieselbe Schreibweise wie `LDAP_ID` in Keycloak; die ersten drei Blöcke stehen
in AD in umgekehrter Byte-Reihenfolge, deshalb stimmt ein naiver Hex-Dump nicht überein.

In Windows den Wert zeigen: AD Users and Computers, Ansicht "Erweiterte Features", Eintrag
Hans, Reiter "Attribut-Editor", `objectGUID` und `distinguishedName`.

### Versuch 2: LDAPS-Anbindung

"Test connection" prüft DNS, TCP, TLS-Kette und Hostnamen; "Test authentication" bindet mit dem
Bind-Konto, nicht mit Hans. Nach "Sync all users" heißt Hans `t01.hans@ad.mustertech.test`,
weil `userPrincipalName` als Username-Attribut gewählt ist. Erst der Login im privaten Fenster
prüft Hans' Passwort gegen AD.

`/api/profile` liefert 200, `/api/urlaubsantraege` liefert 403: Hans hat noch keine Gruppe und
damit keine Rolle `mitarbeiter`. Der Access Token trägt `portal-api` in `aud`; die Portal-API in
diesem Repository prüft Signatur und Issuer, den Audience-Claim zeigt sie im Token, wertet ihn
aber nicht aus. Das ist eine Eigenschaft von `labs/assignments/services/portal-api`, nicht des Workshops.

### Versuch 3: Direkte und rekursive Gruppen

Mit `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE` sucht Keycloak Gruppen, deren `member` Annas DN enthält:
`Mitarbeiter` und `Teamleitung`. `Manager` enthält nur den DN von `Teamleitung`, also fehlt die
Rolle `manager`, und `/api/urlaubsantraege/alle` antwortet 403. Mit
`LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY` folgt Keycloak der Kette und Anna erhält `Manager`.
Nach Gruppen-Sync, Benutzer-Sync und neuem Login antwortet die API 200. Hans bleibt bei 403,
ohne Token 401. Preserve Group Inheritance bleibt aus; sonst entstünde `Manager/Teamleitung` als
Untergruppe und Anna erbte `manager` über die Keycloak-Hierarchie, ohne dass die Strategie eine Rolle spielt.

Access Tokens gelten im Realm 120 Sekunden (`exp - iat`).

### Versuch 4: OU-Wechsel

Der DN wechselt auf `CN=Hans Mueller,OU=Moved,...`, `objectGUID` bleibt. Die Suche unter
`OU=Users` findet ihn nicht mehr, die Suche unter der Team-OU schon. Was Keycloak beim Login
mit dem bereits importierten, jetzt außerhalb der Suchbasis liegenden Benutzer tut, gehört zu
den Ergebnissen des Probelaufs; die Anleitung verspricht deshalb keine stabile Keycloak-ID.
Beobachtet mit Keycloak 26.5.7: Der Login scheitert mit "Invalid user credentials", Keycloak löscht den
lokalen Import, und nach Erweiterung der Users DN entsteht beim Sync ein neuer Keycloak-Benutzer mit
neuer ID und gleicher `LDAP_ID`. Details im Abschnitt "Beobachtungen aus dem Probelauf".

### Versuch 5: Rechteentzug und Deaktivierung

Ein bereits ausgestellter JWT ändert sich nicht. Die API prüft nur Signatur und Issuer und
akzeptiert den alten Token bis `exp`. Keycloak zeigt die fehlende Gruppe erst nach Sync;
ein neuer Token enthält `manager` dann nicht mehr. Bei der Deaktivierung scheitert ein frischer
Login ohne SSO am Bind gegen AD (Fehlercode 533 im LDAP-Diagnosetext, "account disabled").
Der MSAD-Mapper setzt beim Sync `enabled` anhand von `userAccountControl`. Bis dahin laufen
Sitzung und Refresh weiter; erst nach dem Sync lehnt Keycloak den Refresh mit "User disabled" ab,
bestehende Sitzungen bleiben trotzdem in der Sitzungsliste. Zeitstempel im Abschnitt
"Beobachtungen aus dem Probelauf".

### Versuch 6: Rücknahme

Reihenfolge der LDIF-Dateien 04, 05, 06: erst aktivieren und Anna wieder in `Teamleitung`, dann Hans
zurück nach `Users`, weil die LDIF-Dateien 04 und 06 seinen DN unter `OU=Moved` erwarten. Users DN
zurück auf `OU=Users`, Sync, Sitzungen beenden, frische Logins. Ergebnis wie in Versuch 3 mit rekursiver
Strategie: Hans 200 auf `/api/urlaubsantraege` und 403 auf `/alle`, Anna 200 auf beiden.

## Beobachtungen aus dem Probelauf

Probelauf am 15.09.2026 im Projekt `keycloak-qards`, Zone `europe-west3-a`, Image
`windows-server-2022-dc-v20260909`, `e2-standard-2`, gcloud 565.0.0, Keycloak 26.5.7, PostgreSQL 18.
Gastzugang über SSH per IAP, Bereitstellung, Promotion und Vorbereitung dauerten zusammen rund 75 Minuten
einschließlich dreier Neustarts. Trainerprüfung 25 von 25 PASS (mit IAP-Tunnel), Gastprüfung 16 von 16 PASS.

### Versuch 1

`memberOf` von Hans enthält nur `Mitarbeiter`, das von Anna `Teamleitung` und `Mitarbeiter`; `Manager`
hat als einziges `member` den DN von `Teamleitung`. `objectGUID:: S6nBAdsmPkONmfzgwrwP2Q==` ergibt mit
`decode-guid` den Wert `01c1a94b-26db-433e-8d99-fce0c2bc0fd9`, identisch mit `LDAP_ID` in Keycloak.

### Versuch 2 und 3

Provider und Mapper aus der Trainerlösung verbinden sich über LDAPS mit der Workshop-CA; "Sync all users"
meldet beim zweiten Lauf `0 imported users, 2 updated users`. Hans heißt in Keycloak
`t01.hans@ad.mustertech.test`. Ein frischer Login (Passwort gegen AD) liefert einen Token mit
`exp - iat = 120`. Mit direkter Strategie hat Anna die Keycloak-Gruppen `Mitarbeiter` und `Teamleitung`,
`/api/urlaubsantraege/alle` antwortet 403. Nach Umstellung auf `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY`,
Gruppen-Sync und Benutzer-Sync kommt `Manager` hinzu; ein neuer Token enthält `manager`, die API antwortet 200.
Hans bleibt bei 403, ohne Token 401.

### Versuch 4

Nach dem `modrdn` findet die Suche unter `OU=Users` nichts (Exit 0, null Einträge), die Suche unter der
Team-OU liefert den neuen DN mit unveränderter `objectGUID`. Ein Login als Hans mit Users DN `OU=Users`
scheitert mit "Invalid user credentials"; das Keycloak-Ereignis lautet `LOGIN_ERROR` mit
`error=user_not_found`, und Keycloak entfernt dabei den lokalen Import: Hans fehlt danach in **Users**.
Nach Erweiterung der Users DN auf die Team-OU und "Sync all users" ist Hans wieder importiert, mit
**neuer Keycloak-ID** (`3bb7e75d…` wurde `23a07b14…`), gleicher `LDAP_ID` und `LDAP_ENTRY_DN` unter
`OU=Moved`. Der `sub` im Token ändert sich damit ebenfalls; Anwendungen, die Benutzer an `sub` binden,
verlieren die Zuordnung. Die stabile Identität ist `objectGUID`.

### Versuch 5

Anna aus `Teamleitung` entfernt um 17:47:30 UTC, Token `exp` 17:49:30. Der alte Token liefert vor und
nach dem Keycloak-Sync 200 und erst nach `exp` 401: Die API prüft nur Signatur und Ablauf. Nach dem Sync
hat Anna nur noch `Mitarbeiter`; ein neuer Token enthält kein `manager`, die API antwortet 403. Ein Refresh
mit dem noch gültigen Refresh-Token funktioniert und liefert einen Token ohne `manager`, weil Keycloak die
Rollen beim Refresh neu berechnet.

Hans deaktiviert (`userAccountControl` 66050) um 17:47:42 UTC, Hans lag dabei in `OU=Moved`:

| Stelle                                     | Beobachtung                                                        |
| ------------------------------------------ | ------------------------------------------------------------------ |
| Frischer Login ohne SSO                    | "Invalid user credentials", Ereignis `invalid_user_credentials`    |
| Alter Access Token gegen `/api/profile`    | 200 bis `exp`, danach 401                                          |
| Refresh vor dem Sync                       | erfolgreich, neuer Token wird ausgestellt                          |
| **Enabled** in Keycloak vor dem Sync       | `true`                                                             |
| **Enabled** nach "Sync all users"          | `false` (MSAD-Mapper liest `userAccountControl`)                   |
| Refresh nach dem Sync                      | `invalid_grant`, "User disabled"                                   |
| Sitzungen nach dem Sync                    | beide Sitzungen bestehen weiter; der Sync beendet keine Sitzungen  |

### Versuch 6

LDIF 04, 05, 06, Users DN zurück auf `OU=Users`, Sync und "Beende alle Sitzungen": Hans ist aktiviert
(`userAccountControl` 66048), die drei Gruppen entsprechen der Baseline. Frische Logins liefern Hans
200 auf `/api/urlaubsantraege` und 403 auf `/alle`, Anna 200 auf beiden. Hans behält die neue Keycloak-ID
aus Versuch 4. `Reset-Team.ps1 -Team 01` ändert danach nichts mehr.

### Anmeldung, Delegation und Netz

Der Authorization Code Flow mit PKCE (S256) wurde vom Portal bis zur Keycloak-Anmeldeseite im Browser und
für den Code-Tausch per HTTP-Skript geprüft: Token mit `portal-api` in `aud`, API 200, 200, 403 für Hans.
Bind-Konten scheitern beim Schreiben mit LDAP-Fehler 50, Übungskonten beim Nachbarteam ebenso; Änderungen
an eigenen Testobjekten und Gruppen gelingen. Die effektive Firewall erlaubt 636 nur aus der gemeldeten
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

4. Bind: `ldapwhoami -x -H ldaps://... -D t01.bind@ad.mustertech.test -y /secrets/bind.pw`.
   Fehler 49 mit `data 52e` ist ein falsches Passwort, `data 533` ein deaktiviertes Konto.
5. Suche: Basis, Scope und Filter einzeln prüfen. Eine erfolgreiche Suche mit null Treffern hat Exit 0.

Fehlt ein Benutzer in Keycloak: Users DN, Search scope und User LDAP filter prüfen, dann "Sync all users".
Fehlt ein Recht: Strategie des Group-Mappers, Gruppen-Sync, Rollen der Keycloak-Gruppe, Cache und
Ausstellungszeitpunkt des Tokens. Kein Fehler wird durch Abschalten der Zertifikatsprüfung oder
eine weitere Firewallregel gelöst.

## Rücknahme und Reset

Ein Team auf den Ausgangszustand setzen, auf dem DC als Domänen-Administrator:

```powershell
C:\Workshop\scripts\Reset-Team.ps1 -Team 01
```

Das Skript verschiebt Hans und Anna zurück nach `Users`, aktiviert beide, stellt die drei
Mitgliedschaften her und entfernt fremde Mitglieder. Passwörter und Delegation bleiben. In Keycloak
danach `apply-solution.sh users-dn users`, `sync` und `logout-sessions` oder die entsprechenden
Klicks in der Admin-Konsole.

## Ersatz mit OpenLDAP

Ohne GCP läuft die Einheit mit Lab 07c und dem [Begleitmaterial](../ldap-ad/README.md).
Versuch 1, 3 (Gruppenänderung per LDIF), 5 (Rechteentzug) und 6 laufen dort gleichwertig,
mit `entryUUID` statt `objectGUID` und `groupOfNames` statt `group`. Versuch 2 entfällt bis auf
den Provider aus Lab 07c ohne TLS. Versuch 4 lässt sich mit `ldapmodrdn` nachstellen; die
AD-spezifischen Teile (MSAD-Mapper, `userAccountControl`, Zertifikatskette gegen Windows)
werden anhand des Abschnitts "Beobachtungen aus dem Probelauf" besprochen und als Aufzeichnung genannt.

## Abbau

Zeitpunkt mit der Kursleitung abstimmen; die Umgebung bleibt bis zum Ende der Auswertung stehen.

```powershell
./Remove-Workshop.ps1 -PlanOnly
./Remove-Workshop.ps1
./Remove-Workshop.ps1 -Local   # zusaetzlich den lokalen Compose-Stack samt Volumes entfernen
```

Der Abbau prüft Projektnummer, selfLink und Labels jeder Ressource, entfernt zuerst die
IAP-Bindung, dann Instanz, Datendisk, Bootdisk, Adressen, Firewallregeln, Subnetz und VPC.
Danach mit `--filter="name~'^kcad-'"` in `gcloud compute instances list`, `disks list`,
`addresses list`, `firewall-rules list` und `networks list` bestätigen, dass nichts übrig ist.
Das Projekt, die aktivierten APIs und fremde IAM-Bindungen bleiben erhalten.
