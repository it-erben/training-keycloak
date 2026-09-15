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
Mögliche Ausgänge: Keycloak findet den Benutzer nicht mehr und entfernt oder deaktiviert den
lokalen Import, oder der Login scheitert mit "Invalid username or password". Nach Erweiterung
der Users DN auf die Team-OU findet Keycloak Hans über `objectGUID` wieder; ob dabei derselbe
Keycloak-Datensatz weiterverwendet oder ein neuer angelegt wird, zeigt der Vergleich der Benutzer-ID.

### Versuch 5: Rechteentzug und Deaktivierung

Ein bereits ausgestellter JWT ändert sich nicht. Die API prüft nur Signatur und Issuer und
akzeptiert den alten Token bis `exp`. Keycloak zeigt die fehlende Gruppe erst nach Sync;
ein neuer Token enthält `manager` dann nicht mehr. Bei der Deaktivierung scheitert ein frischer
Login ohne SSO am Bind gegen AD (Fehlercode 533 im LDAP-Diagnosetext, "account disabled").
Der MSAD-Mapper setzt beim Import `enabled` anhand von `userAccountControl`; ob eine bestehende
Keycloak-Sitzung, das SSO-Cookie und der Refresh weiterlaufen, hängt von Cache und Sitzung ab und
wird im Probelauf mit Zeitstempeln festgehalten.

### Versuch 6: Rücknahme

Reihenfolge der LDIF-Dateien 04, 05, 06: erst aktivieren und Anna wieder in `Teamleitung`, dann Hans
zurück nach `Users`, weil die LDIF-Dateien 04 und 06 seinen DN unter `OU=Moved` erwarten. Users DN
zurück auf `OU=Users`, Sync, Sitzungen beenden, frische Logins. Ergebnis wie in Versuch 3 mit rekursiver
Strategie: Hans 200 auf `/api/urlaubsantraege` und 403 auf `/alle`, Anna 200 auf beiden.

## Beobachtungen aus dem Probelauf

Der Probelauf auf GCP steht noch aus. Dieser Abschnitt erhält nach dem vollständigen Aufbau die
tatsächlich beobachteten Ergebnisse mit Zeitpunkt, Keycloak-Version, Image-Name und Konfiguration,
insbesondere zu Versuch 4 (Import nach OU-Wechsel), Versuch 5 (Sitzung, SSO, Refresh, alter Token)
und zum Neustart der VM.

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
