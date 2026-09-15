# AD-Workshop für Tag 3: Keycloak an Windows Server auf GCP anbinden

## Ziel und Entwurfsgrundlage

Sechs Teilnehmer bearbeiten in drei Zweiergruppen einen 90-minütigen Workshop.
Sie verbinden ihr lokales Keycloak mit einem vorbereiteten Microsoft Active Directory
und verfolgen Änderungen vom Verzeichnis bis zum Zugriff auf die Portal-API.
Vorausgesetzt werden Modul 06b und der LDAP-Block aus Modul 07 einschließlich Lab 07c.

Der Entwurf verwendet die im Gespräch empfohlene Variante: einen eigenen Windows-Server
mit AD DS auf Google Compute Engine. Die Bereitstellung erfolgt direkt über die gcloud CLI.
GCP ist die ausdrücklich gewählte Plattform. Ein konkretes Projekt mit aktivierter Abrechnung,
IAM-Berechtigungen, Quota und Organisationsrichtlinien wurde für diese Spec nicht geprüft.
Diese Spec beschreibt die spätere Umsetzung; sie legt keine Cloud-Ressourcen an.

Der fachliche Kern besteht aus vier Fragen:

- Wie findet Keycloak einen AD-Benutzer und prüft dessen Passwort?
- Wie werden direkte und verschachtelte Gruppen zu Anwendungsrollen?
- Was passiert bei einem OU-Wechsel mit DN, objectGUID und Suchbereich?
- Wann wirken Gruppenentzug und Kontodeaktivierung auf Login, Sitzung und API-Zugriff?

## Auswahl des Verzeichnisdienstes

Ein selbst verwaltetes AD DS erlaubt kontrollierte Änderungen an Benutzern, Gruppen und OUs.
Die zusätzliche Einrichtung wird vor dem Workshop erledigt. Ein einzelner Domain Controller
genügt für dieses kurzlebige Testverzeichnis; Hochverfügbarkeit wird damit nicht demonstriert.
Google beschreibt den Aufbau eines AD-Forests auf Compute Engine in der
[Bereitstellungsanleitung][gcp-ad]. Der Workshop reduziert deren umfangreicheren Aufbau
auf ein Projekt und einen Domain Controller.

Entra Domain Services bleibt eine Alternative für einen späteren Schwerpunkt zu verwalteten
Verzeichnissen. Aus Entra ID synchronisierte Objekte bringen jedoch Einschränkungen und
Synchronisationszeiten in die Versuche. Eigene OUs wären dort möglich, für die vorliegenden
Lernziele aber ein weiterer erklärungsbedürftiger Sonderfall. Siehe [Synchronisierung][entra-sync].

OpenLDAP aus Lab 07c bleibt der lokale Ersatz bei fehlender GCP-Verfügbarkeit. Dieser Ersatz
deckt Suche und Gruppenänderungen ab; AD-spezifische Versuche werden dann anhand von zuvor
aufgezeichneten Ergebnissen besprochen und ausdrücklich als solche gekennzeichnet.

## Architektur und Verantwortlichkeiten

```text
Browser der Zweiergruppe
  | OIDC Authorization Code + PKCE
  v
Lokales Portal -- Access Token --> lokale Portal-API
  |                                 |
  +------------ lokales Keycloak ----+ Signatur, Issuer und Audience
                      |
                      | LDAPS, TCP 636, Zertifikatsprüfung
                      v
              GCP-Testdomäne auf dc01
              OU Team01 / Team02 / Team03
```

Pro Zweiergruppe bedient ein Teilnehmer den lokalen Stack; beide wechseln sich bei den Versuchen ab.
Der Stack enthält Keycloak, PostgreSQL, das vorhandene Portal, die Portal-API und ein LDAP-Werkzeug.
Er verwendet einen eigenen Compose-Projektnamen und projektbezogene Volumes ohne globale
`container_name`- oder Volume-Namen. Es läuft jeweils nur ein Portal-Stack pro Rechner, mit den
bekannten Ports 8080, 5173 und 3001. Vorherige Labs werden gezielt beendet; ein globales Docker-Prune
ist kein Bestandteil des Starts.

Im freigegebenen GCP-Projekt entsteht eine eigene Custom-Mode-VPC mit einem regionalen Subnetz,
gezielten VPC-Firewallregeln, reservierter interner und externer IPv4-Adresse und einer
Windows-Server-VM. AD-Datenbank, Logs und SYSVOL liegen auf einer separaten zonalen Persistent Disk.
Bootdisk und Datendisk verwenden pd-balanced; Local SSD und Spot-VMs werden nicht verwendet.
Alle Ressourcen erhalten einen eindeutigen Namenspräfix und, soweit unterstützt, Workshop-Labels.
Die Testdomäne erhält keine Verbindung zu Firmenverzeichnissen; die Default-VPC bleibt unberührt.

Die VM besitzt keine angehängte Google-Service-Account-Identität und benötigt für die AD-Funktion
keine Cloud-API-Rechte. Die interne Adresse bleibt über die Reservierung stabil. DNS für die eigene
AD-Zone beantwortet der DC; andere Anfragen werden an den Compute-Engine-Metadatenresolver
weitergeleitet. Windows-Aktivierung, Updates und Zeitsynchronisation müssen weiterhin funktionieren.
Der Probelauf prüft insbesondere die Erreichbarkeit von `kms.windows.googlecloud.com`.
Siehe [Windows-VMs][gcp-windows] und [AD-Betrieb auf GCP][gcp-ad-practices].

Der Trainer bereitet AD, DNS, Zertifikate und Konten vor, damit die Teilnehmer mit ihren
lokalen Werkzeugen arbeiten können und weder GCP-IAM-Rollen noch eine RDP-Sitzung oder
Domain-Admin-Rechte benötigen. Die AD-Ansicht in Windows wird vom Trainer gezeigt.
Teilnehmer führen vorbereitete LDAP-Lese- und Änderungsbefehle mit delegierten Übungskonten aus.

## Netzwerk und TLS

Der Entwurf verwendet einen kurzzeitig erreichbaren LDAPS-Endpunkt mit Quell-IP-Beschränkung.
Das ermöglicht die Anbindung der vorhandenen lokalen Container ohne Domain Join oder VPN.
Diese Erreichbarkeit gehört zur späteren, konkret zu bestätigenden Bereitstellung.

- TCP 636 ist ausschließlich für die öffentlichen Ausgangs-IP-Adressen der drei Gruppen erlaubt.
- TCP 3389 ist ausschließlich aus dem IAP-TCP-Forwarding-Bereich `35.235.240.0/20` erlaubt, mit NLA.
  Der Trainer verbindet sich über `gcloud compute start-iap-tunnel` und einen lokalen RDP-Port.
  IAP-Zugriff wird auf den Trainer, die Workshop-VM und TCP 3389 begrenzt.
- DNS, LDAP 389, SMB, RPC, Kerberos und WinRM werden nicht aus dem Internet freigegeben.
- Die VPC-Firewallregeln gelten nur für den Workshop-DC über einen eindeutigen Network Tag.
  Die Windows-Firewall ergänzt sie; keine Regel erlaubt eingehenden Zugriff aus `0.0.0.0/0`.
- Verhindert eine GCP-Organisationsrichtlinie diesen Aufbau, wird keine Ausnahme umgangen.
  Eine private Zugangsvariante braucht dann einen angepassten Entwurf.

Der IAP-Aufbau folgt der [Google-Anleitung für TCP Forwarding][gcp-iap]. IAP authentifiziert
den Tunnel; die Windows-Anmeldung mit dem vorbereiteten Administratorkonto bleibt erforderlich.

Die interne Testdomäne heißt `ad.mustertech.test`, der DC `dc01.ad.mustertech.test`.
Der lokale LDAP-Werkzeugcontainer und Keycloak lösen diesen Namen über einen expliziten
Compose-Hosteintrag auf die öffentliche Test-IP auf. Ein Eintrag nur auf dem Host genügt nicht.
Der Domain Controller selbst verwendet seine interne AD-DNS-Auflösung.

Eine eigens erzeugte Workshop-CA stellt das Serverzertifikat aus. Es enthält den DC-FQDN im SAN,
Server-Authentication-EKU und einen privaten Schlüssel im passenden Windows-Zertifikatsspeicher.
An Teilnehmer wird ausschließlich das öffentliche CA-Zertifikat verteilt. Keycloak lädt es über
`KC_TRUSTSTORE_PATHS`; das LDAP-Werkzeug verwendet dieselbe CA. Hostnamenprüfung und TLS-Prüfung
bleiben aktiv. Das Serverzertifikat und die CA gelten bis nach dem freigegebenen Workshop-Ende.
Grundlagen: [Microsoft LDAPS][ldaps] und [Keycloak Truststore][truststore].

## AD-Datenmodell und Gruppenisolation

Die Domäne enthält `OU=Workshop,DC=ad,DC=mustertech,DC=test` mit `Team01`, `Team02` und `Team03`.
Unter jeder Team-OU liegen `Users`, `Moved`, `Groups` und `ServiceAccounts`.
Die Beispiele verwenden Team01; für die anderen Teams werden alle `t01`-Präfixe ersetzt.

| Objekt          | sAMAccountName | UPN oder Aufgabe                       |
| --------------- | -------------- | -------------------------------------- |
| Hans Mueller    | t01.hans       | `t01.hans@ad.mustertech.test`          |
| Anna Schmidt    | t01.anna       | `t01.anna@ad.mustertech.test`          |
| Bind-Konto      | t01.bind       | LDAP-Suche für Keycloak                |
| Übungskonto     | t01.operator   | Vorbereitete Änderungen in der Team-OU |
| Mitarbeiter     | t01.staff      | Direkte Mitglieder Hans und Anna       |
| Teamleitung     | t01.leads      | Direktes Mitglied Anna                 |
| Manager         | t01.managers   | Enthält zunächst nur Teamleitung       |

Die Gruppennamen in der ersten Spalte sind die `cn`-Werte innerhalb der jeweiligen Gruppen-OU.
Alle drei Gruppen sind AD-Sicherheitsgruppen mit kompatiblem Gruppenscope für diese Verschachtelung.
Initial hat Anna Managerrechte ausschließlich über `Teamleitung` als Mitglied von `Manager`.
Hans hat keine direkte oder indirekte Managerzuordnung.

Das Bind-Konto erhält keine Schreibrechte. Das Übungskonto darf an den beiden Testbenutzern
die vorgesehenen Attribute ändern und sie zwischen `Users` und `Moved` verschieben sowie
Mitgliedschaften der drei Testgruppen bearbeiten. Es darf keine Dienstkonten, fremden Team-OUs
oder Domänenrichtlinien ändern. Berechtigungen dafür werden explizit delegiert und negativ getestet.
OU-Trennung begrenzt die Übungen und delegierten Schreibrechte; sie garantiert keine umfassende
Lesetrennung innerhalb einer AD-Domäne. Das Verzeichnis enthält ausschließlich fiktive Daten.

Kennwörter für Benutzer, Bind-Konten, Übungskonten, Administrator und DSRM werden getrennt erzeugt.
Die öffentlichen Lab-Kennwörter `admin` und `test1234` werden in GCP nicht verwendet.
Geheimnisse, PFX-Dateien und CA-Schlüssel bleiben außerhalb des Repositorys und außerhalb von Logs.
Passwörter sind in Teilnehmerbefehlen interaktive Eingaben oder geschützte lokale Dateien.

## Keycloak und Anwendung

Ausgangspunkt ist die geprüfte Kurslinie Keycloak 26.5, für diesen Aufbau fest auf 26.5.7 gesetzt.
PostgreSQL verwendet die Hauptversion 18 mit Mount auf `/var/lib/postgresql`.
Die Umsetzung hält die tatsächlich verwendeten Image-Digests im lokalen Prüfbericht fest.
Windows Server 2022 Datacenter ist die festgelegte Serverbasis. Die Image-Familie `windows-2022`
aus dem öffentlichen Projekt `windows-cloud` wird vor Bereitstellung auf einen konkreten Image-Namen
aufgelöst. Dieser Name wird beim Erstellen verwendet und für den Durchlauf festgehalten.
Als Maschinentyp ist `e2-standard-2` mit 2 vCPU und 8 GiB RAM vorgesehen; die Verfügbarkeit in der
gewählten Zone wird vorab geprüft. Bootdisk 64 GiB und AD-Datendisk 20 GiB sind die Ausgangsgrößen.

Der Realm heißt weiterhin `mustertech`. Portal-Client, API-Audience und Rollen stammen aus
Modul 06b. Der neue Import enthält keine lokalen Konten mit den Namen der AD-Testbenutzer.
Keycloak-Admin und Bootstrap-Konto bleiben lokal, damit ein LDAP-Fehler die Reparatur nicht verhindert.
Die spätere Aufgabe enthält einen unvollständigen LDAP-Provider; eine separate Trainerlösung
stellt den vollständigen Endzustand bereit.

Für den LDAP-Provider gelten:

- Vendor Active Directory, READ_ONLY, Import Users eingeschaltet und LDAPS auf Port 636.
- `userPrincipalName` als Username LDAP attribute, `cn` als RDN und `objectGUID` als UUID-Attribut.
- Users DN zunächst `OU=Users,OU=Team01,OU=Workshop,DC=ad,DC=mustertech,DC=test`, Scope Subtree.
- Benutzerfilter für Hans und Anna; Bind- und Übungskonten dürfen nicht ins Portal gelangen.
- Attributzuordnung für Vorname, Nachname und Mail sowie MSAD User Account Mapper.
- Group Mapper mit Groups DN der Team-OU und lesender Abbildung nach Keycloak.
- Zunächst direkte, anschließend AD-rekursive Gruppenauflösung. Die genaue UI-Auswahl und
  resultierende Provider-Konfiguration müssen an Keycloak 26.5.7 praktisch belegt werden.

Die Keycloak-Gruppe `Mitarbeiter` erhält die Realm-Rolle `mitarbeiter`, `Manager` die Rolle `manager`.
Ein neuer Access Token enthält die zulässigen Rollen in `realm_access.roles` und `portal-api` als Audience.
Die API prüft weiterhin Signatur, Issuer und Audience. Die Abnahme verwendet die bestehenden Endpunkte
`/api/profile`, `/api/urlaubsantraege` und `/api/urlaubsantraege/alle`.
Es werden keine zusätzlichen Token- oder Berechtigungsendpunkte benötigt.

## Workshop-Ablauf und erwartete Ergebnisse

| Minuten | Versuch                         | Nachweis                                            |
| ------- | ------------------------------- | --------------------------------------------------- |
| 0-15    | AD-Einträge lesen               | DN, UPN, GUID und direkte Mitglieder identifizieren |
| 15-35   | Keycloak über LDAPS verbinden   | Hans meldet sich frisch am Portal an                |
| 35-55   | Verschachtelte Gruppe auflösen  | Anna erhält manager; Hans erhält HTTP 403           |
| 55-65   | Hans in Moved verschieben       | DN ändert sich; GUID bleibt identisch               |
| 65-80   | Rechte entziehen, Konto sperren | LDAP, Keycloak, Sitzung und API getrennt beobachten |
| 80-90   | Rücknahme und Auswertung        | Ausgangszustand wiederhergestellt und erklärt       |

Der Trainer zeigt für den ersten Versuch AD Users and Computers mit eingeblendeten Attributen.
Die Teilnehmer lesen dieselben Einträge über LDAPS. Eine dokumentierte Ausgabe zeigt die GUID
in vergleichbarer Form; Binärwerte dürfen nicht mit dem Keycloak-Subject verwechselt werden.

Bei direkter Gruppenauflösung fehlen Anna zunächst die indirekten Managerrechte; erst nach passender
rekursiver Auflösung, gezielter Aktualisierung und neuem Token liefert der Manager-Endpunkt HTTP 200.
Hans erhält dort mit gültigem Mitarbeiter-Token HTTP 403; ohne Token erhält die API HTTP 401.

Vor dem OU-Wechsel werden Hans' DN, GUID und Keycloak-Benutzer-ID notiert, damit die Gruppe
anschließend den veränderten Verzeichnisnamen von der stabilen AD-Identität und dem lokalen Import
unterscheiden kann. Nach dem Verschieben
ist er außerhalb der ursprünglichen Suchbasis. Eine LDAP-Suche unter der Team-OU findet ihn wieder.
Die Teilnehmer erweitern Users DN auf die Team-OU, behalten aber den Filter für die Testbenutzer.
Keycloaks Umgang mit einem bereits importierten, zwischenzeitlich nicht auffindbaren Benutzer wird
im Probelauf ermittelt. Die Anleitung darf keine stabile Keycloak-ID versprechen: Der Versuch
muss auch einen möglichen gelöschten oder deaktivierten lokalen Import erklären.

Für den Rechteentzug wird Anna aus `Teamleitung` entfernt. Ein vorher ausgestelltes JWT bleibt
inhaltlich unverändert. Nach Aktualisierung und frischer Token-Ausstellung fehlen Managerrechte.
Die rein JWT-prüfende API kann einen noch gültigen alten Token weiterhin akzeptieren.
Access Tokens gelten im Workshop 120 Sekunden; gemessene Zeiten werden mit `iat` und `exp` notiert.

Danach wird Hans' Konto deaktiviert. Ein frischer Login ohne SSO muss scheitern.
Bestehende Keycloak-Sitzung, Anwendungssitzung und Refresh werden separat getestet und protokolliert.
Ein bereits ausgestellter Token wird bis zu seiner Gültigkeitsgrenze gegen die API getestet.
Für Refresh und bestehendes SSO enthält die spätere Musterlösung die tatsächlich beobachteten
Ergebnisse der festgelegten Provider-, Mapper- und Cache-Konfiguration.

Jede Änderung hat eine passende Rücknahme. Hans kehrt nach `Users` zurück, sein Konto wird aktiviert,
Anna wird erneut Mitglied von `Teamleitung`. Suchbasis und Filter werden zurückgesetzt;
Gruppen werden aktualisiert und Test-Benutzersitzungen beendet. Frische Logins und beide
API-Berechtigungsfälle bestätigen den Ausgangszustand.

## Ablage und Schnittstellen der späteren Umsetzung

Das Paket entsteht unter `workshops/active-directory/`, ohne Umnummerierung der bestehenden Labs.
`workshops/README.md` und das LDAP-Begleitmaterial erhalten einen Verweis auf die optionale Tag-3-Einheit.
Modul 07 bleibt das fachliche Hauptdeck. Ein zusätzliches Foliendeck ist für diesen Workshop nicht nötig.

| Geplanter Pfad unter workshops/active-directory/ | Verantwortung                                    |
| ------------------------------------------------ | ------------------------------------------------ |
| README.md                                        | Voraussetzungen, Start, Dauer und Ressourcen     |
| aufgabe.md                                       | Versuche mit Vorhersagen und Ergebnissen         |
| trainer.md                                       | Musterlösung, Diagnose, Rücknahme und Ersatz     |
| scripts/New-Workshop.ps1                         | GCP-Ressourcen per gcloud mit Inventar erfassen  |
| scripts/Initialize-Domain.ps1                    | AD DS, DNS, Datenträger und Neustartphasen       |
| scripts/Initialize-Workshop.ps1                  | Zertifikat, Team-OUs, Konten und Delegation      |
| scripts/Test-Workshop.ps1                        | AD-Zustand, LDAPS und delegierte Schreibgrenzen  |
| scripts/Reset-Team.ps1                           | Rücknahme für ein bestimmtes Team                |
| scripts/Remove-Workshop.ps1                      | Abbau anhand geprüfter Ressourcen-IDs            |
| lab/docker-compose.yml                           | Lokaler Stack einschließlich LDAP-Werkzeug       |
| lab/realm-import.json                            | Vorbereitete Anwendung, LDAP bleibt Lernaufgabe  |
| solution/                                        | Gesonderte vollständige Trainerkonfiguration     |

Bereitstellung und Abbau erfolgen mit `gcloud`, aufgerufen aus PowerShell 7 auf dem Trainerrechner.
Bicep und Terraform sind nicht Bestandteil der Umsetzung. `New-Workshop.ps1` unterstützt
`-PlanOnly`: Es prüft Eingaben und vorhandenen Zustand und gibt die vorgesehenen Änderungen aus,
ohne APIs zu aktivieren, IAM zu ändern oder Ressourcen anzulegen. Das ist eine lokale Vorprüfung,
keine serverseitige Simulation aller gcloud-Mutationen.

Jeder gcloud-Aufruf erhält explizit `--project` und bei regionalen beziehungsweise zonalen Ressourcen
zusätzlich Region oder Zone. Eine Änderung der globalen aktiven gcloud-Konfiguration ist nicht nötig.
Die Skripte verwenden diese Befehlsgruppen mit strukturierten JSON-Ausgaben:

- `gcloud projects describe`, `gcloud billing projects describe`, `gcloud services list` und
  Compute-Engine-Describe-Aufrufe für Identität, Billing, APIs, Quota und vorhandene Ressourcen.
- `gcloud compute images describe-from-family windows-2022 --project=windows-cloud`
  zum Festhalten der konkreten Windows-Image-Version; hier ist das öffentliche Image-Projekt korrekt.
- `gcloud compute networks create`, `networks subnets create`, `addresses create`,
  `firewall-rules create`, `disks create` und `instances create` für den freigegebenen Aufbau.
- `gcloud compute start-iap-tunnel` für den RDP-Zugang des Trainers.
- Die zugehörigen `describe`- und `delete`-Befehle für Prüfung und gezielten Abbau.

AD-Konfiguration verwendet PowerShell im Windows-Gast. Für den ersten Zugang wird vor der
DC-Promotion mit `gcloud compute reset-windows-password` ein dediziertes lokales Administratorkonto
eingerichtet. Danach werden die geprüften PowerShell-Skripte über die IAP-RDP-Sitzung übertragen
und mit getrennt eingegebenen Geheimnissen ausgeführt. Neustartphasen haben eindeutige Fortsetzungspunkte.
Die nötigen Domänenadministrator-Zugangsdaten werden vor dem Abschalten des Gast-Account-Managers geprüft.
Nach der Promotion wird dieser gemäß Google-Anleitung deaktiviert: Ein späterer gcloud-Passwortreset
könnte sonst Domänenkonten verändern. Siehe [Windows-Zugangsdaten][gcp-credentials].
Geheimnisse werden weder als VM-Metadaten noch als Klartext-Startskripte hinterlegt.
Teilnehmerbefehle werden für Bash und PowerShell dokumentiert und auf beiden Plattformen getestet.
Portal und API werden aus `labs/assignments/services/` wiederverwendet. Ausgangskonfigurationen
stehen unter `labs/assignments/modul-06b-client-management/` und `modul-07c-ldap-federation/`.
Ein gemeinsamer Codepfad wird nur geändert, wenn die Abnahme einen konkreten Fehler nachweist.

Damit sich ein Durchlauf später nachvollziehen und gezielt abbauen lässt, erzeugt die Vorbereitung
ein lokales, nicht versioniertes Manifest mit Projekt-ID und Projektnummer,
Region, Zone, eindeutigen Ressourcen-IDs und Self-Links, Namenspräfix, interner und externer IP,
neu angelegten IAM-Bindungen, DC-FQDN, CA-Fingerprint, Team-DNs,
Versionsnachweisen und Ablaufzeitpunkt. Geheimnisse liegen separat. Dieses Manifest ist Grundlage
für Teilnehmerkonfiguration, Tests und Abbau. Skripte prüfen vorhandene Objekte und brechen bei
widersprüchlichem Zustand ab, statt eine bestehende Domäne erneut zu promoten oder Daten zu überschreiben,
denn ein abgebrochener erster Versuch darf beim erneuten Start keine fremden Ressourcen gefährden.

## Kosten und Voraussetzungen der Ausführung

Vor einem kostenpflichtigen Deployment müssen diese Werte konkret vorliegen:

- GCP-Projekt-ID, Projektnummer, verknüpftes Billing-Konto, Region und Zone.
- Aktive gcloud-Identität und IAM-Rechte zum Verwalten der eigenen Compute-/Netzwerkressourcen;
  für den Trainer zusätzlich IAP-Tunnelzugriff und die erforderlichen Lesezugriffe auf die VM.
- Aktivierte Compute Engine API und IAP API. Fehlende APIs oder Rollen werden vor einer Änderung
  konkret benannt; bestehende IAM-Policies werden nicht pauschal ersetzt.
- Öffentliche Ausgangs-IP-Adressen der Gruppen und Erreichbarkeit von TCP 636 sowie IAP vom Schulungsnetz.
- Verfügbarkeit und Quota für Windows Server 2022 mit 2 vCPU und mindestens 8 GiB RAM.
- Kalkulation für Compute Engine, Windows-Server-Lizenzaufschlag, Boot-/Datendisk,
  reservierte externe IPv4-Adresse und gegebenenfalls ausgehenden Datenverkehr.
- Freigegebenes Gesamtbudget in EUR sowie Start- und Abbauzeitpunkt, höchstens 48 Stunden auseinander.

Die Berechnung berücksichtigt die gewählte Region und Nutzungsdauer anhand der
[Compute-Engine-Preise][gcp-pricing]. Das öffentliche Windows-Image bringt einen gesonderten
Lizenzkostenanteil mit; die Kalkulation setzt keine kostenlose Windows-Nutzung oder BYOL voraus.
Cloud-Billing-Budgetwarnungen sind kein harter Ausgabenstopp. Auch eine gestoppte VM hinterlässt
kostenpflichtige Persistent Disks und gegebenenfalls reservierte externe IP-Adressen.
Vorbereitung und vollständiger Probelauf finden vor dem Workshop statt; die 90 Minuten enthalten
keine Cloud-Bereitstellung. Scheitern Kostenfreigabe, Quota, Richtlinien oder Netztest, bleibt das
OpenLDAP-Lab verfügbar. Es erfolgt kein stiller Wechsel auf größere VMs oder zusätzliche Dienste.

## Abnahme und Fehlerdiagnose

Die spätere Umsetzung gilt erst nach einem vollständigen frischen Aufbau und Rückbau als geprüft.
Zu jedem Ergebnis werden Zeitpunkt, Versionen, Konfiguration und tatsächliche Beobachtung notiert.
Geheimnisse und vollständige gültige Tokens gehören nicht in öffentliche Prüfberichte.

- Der gcloud-basierte PlanOnly-Modus ist nachweislich frei von Mutationen; ungültige Eingaben werden abgewiesen.
- Nur manifestierte Workshop-Ressourcen im freigegebenen Projekt werden verändert.
  Bereits vorhandene gleichnamige Ressourcen ohne passenden Eigentumsnachweis führen zum Abbruch.
- LDAPS aus erlaubten Quellen und RDP über IAP funktionieren; direkte öffentliche RDP-Verbindungen scheitern.
- Effektive VPC- und übergeordnete Firewall-Policies erlauben keine breiteren Zugriffe auf den Workshop-DC.
- LDAPS mit richtiger CA und richtigem Namen funktioniert; falsche CA und falscher Name müssen scheitern.
- Hans und Anna können sich im Browser mit Authorization Code und PKCE anmelden.
- Alle drei Team-Konfigurationen liefern ausschließlich die vorgesehenen Benutzer und Gruppen an Keycloak.
- Delegierte Änderungen in der eigenen OU funktionieren; Schreibversuche gegen fremde Testobjekte werden verweigert.
- Direkte und rekursive Gruppenauflösung liefern die beschriebenen unterschiedlichen API-Ergebnisse.
- OU-Wechsel, Rechteentzug, Kontodeaktivierung und Rücknahme sind mit frischen und vorhandenen Tokens durchgespielt.
- Bash- und PowerShell-Anleitungen wurden praktisch ausgeführt; Dokumentationsprüfungen ersetzen diese Tests nicht.
- VM, Boot-/Datendisk, beide Adressreservierungen, Firewallregeln, Subnetz und VPC sind nach dem Abbau entfernt.
- Nur für den Workshop hinzugefügte IAM-Bindungen sind gezielt entfernt; bestehende Bindungen bleiben erhalten.
- Bestehende lokale Labs, Volumes und fremde GCP-Ressourcen sind unverändert geblieben.

Bei Verbindungsfehlern wird zuerst DNS, dann TCP, dann TLS, dann Bind und zuletzt die Suche geprüft.
Ein fehlender Benutzer erfordert die Prüfung von Suchbasis, Scope und Filter; ein fehlendes Recht
zusätzlich Gruppenauflösung, Mapper, Cache und Token-Ausstellungszeitpunkt.
Fehlschläge führen nicht zum Abschalten der Zertifikatsprüfung oder zu breiteren Firewallregeln.

Der Abbau prüft Projekt-ID, Projektnummer, Region, Zone und die vollständigen Ressourcen-IDs
gegen das lokale Manifest. Er entfernt zuerst die VM, anschließend verbleibende Disks und
Adressreservierungen und zuletzt Firewallregeln, Subnetz und VPC. Eine bereits automatisch mit
entfernte Bootdisk wird als erledigt erkannt. Abhängigkeiten, fremde Ressourcen oder abweichende IDs
führen zum Abbruch der betroffenen Löschung. Das GCP-Projekt selbst wird nicht gelöscht.
Ein unvollständiger Aufbau wird anhand seiner tatsächlich erzeugten Ressourcen ebenfalls bereinigt.
Zusätzlich erteilte IAM-Bindungen werden anhand von Principal, Rolle, Bedingung und Ressource entfernt;
vorhandene Bindungen und aktivierte Projekt-APIs bleiben erhalten.
Lokale Container und Volumes werden ausschließlich über den Workshop-Compose-Projektnamen entfernt.
Ein Neustart der VM muss den eingerichteten AD-Zustand und die LDAPS-Funktion erhalten.

## Abgrenzung und Übergabe

Nicht enthalten sind Entra Connect, Entra-Synchronisation, produktive Konten, Forest Trusts,
mehrere Domain Controller, Schema-Erweiterungen oder eine Windows-SSO-Einrichtung.
Kerberos/SPNEGO bleibt eine Erklärung zum Ausblick. Der Workshop zeigt LDAP-Passwortanmeldung
gegen AD; er behauptet keine Übernahme einer bestehenden Windows-Anmeldung.

Aus dieser Spec wird bei Wiederaufnahme zuerst ein Superpowers-Implementierungsplan unter
`docs/superpowers/plans/` abgeleitet. Die Plattform ist GCP mit gcloud; vor der Ausführung werden
konkretes Projekt und Netzwerkzugang mit dem Nutzer abgeglichen. Der Plan übernimmt Abnahmekriterien, Eingaben und
Ressourcengrenzen übernehmen. Die GCP-Bereitstellung beginnt erst nach der konkreten Freigabe
von Zielprojekt, Ressourcen, Zugriff und kalkuliertem Budget.

## Quellen

- [Google: AD-Forest auf Compute Engine][gcp-ad]
- [Google: AD-Betrieb auf GCP][gcp-ad-practices]
- [Google: Windows-VMs erstellen][gcp-windows]
- [Google: IAP TCP Forwarding][gcp-iap]
- [Google: Windows-Zugangsdaten][gcp-credentials]
- [Google: Compute-Engine-Preise][gcp-pricing]
- [Microsoft: LDAPS-Zertifikate für AD DS][ldaps]
- [Keycloak: Vertrauenswürdige Zertifikate][truststore]
- [Microsoft: Synchronisierung bei Entra Domain Services][entra-sync]
- [Keycloak 26.5.0: LDAP-Provider und Mapper][keycloak-ldap]

[gcp-ad]: https://docs.cloud.google.com/architecture/deploy-an-active-directory-forest-on-compute-engine
[gcp-ad-practices]: https://docs.cloud.google.com/compute/docs/instances/windows/best-practices
[gcp-windows]: https://docs.cloud.google.com/compute/docs/instances/windows/creating-managing-windows-instances
[gcp-iap]: https://docs.cloud.google.com/iap/docs/using-tcp-forwarding
[gcp-credentials]: https://docs.cloud.google.com/compute/docs/instances/windows/generating-credentials
[gcp-pricing]: https://cloud.google.com/products/compute/pricing
[ldaps]: https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/enable-ldap-over-ssl-3rd-certification-authority
[truststore]: https://www.keycloak.org/server/keycloak-truststore
[entra-sync]: https://learn.microsoft.com/en-us/entra/identity/domain-services/synchronization
[keycloak-ldap]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/server_admin/topics/user-federation/ldap.adoc
