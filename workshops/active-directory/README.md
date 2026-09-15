# Workshop: Keycloak an Active Directory auf GCP

Sechs Teilnehmer verbinden in drei Zweiergruppen ihr lokales Keycloak per LDAPS mit einem
vorbereiteten Active Directory und verfolgen Änderungen im Verzeichnis bis zur Portal-API.
Das Verzeichnis läuft als Windows Server 2022 mit AD DS auf Google Compute Engine; der
Trainer stellt es vor dem Kurs bereit und baut es danach wieder ab. Die 90 Minuten
enthalten keine Cloud-Bereitstellung.

Voraussetzungen der Teilnehmer: Modul 06b (Portal und Portal-API), Modul 07 mit Lab 07c
(LDAP-Provider, Group-Mapper) und Docker Compose. Voraussetzungen des Trainers: PowerShell 7,
gcloud CLI, ein RDP-Client und ein GCP-Projekt mit aktivierter Compute Engine API und IAP API.

## Ablauf

| Minuten | Versuch                         | Nachweis                                            |
| ------- | ------------------------------- | --------------------------------------------------- |
| 0-15    | AD-Einträge lesen               | DN, UPN, GUID und direkte Mitglieder identifiziert  |
| 15-35   | Keycloak über LDAPS verbinden   | Hans meldet sich frisch am Portal an                |
| 35-55   | Verschachtelte Gruppe auflösen  | Anna erhält `manager`, Hans erhält HTTP 403         |
| 55-65   | Hans nach `Moved` verschieben   | DN ändert sich, objectGUID bleibt                   |
| 65-80   | Rechte entziehen, Konto sperren | LDAP, Keycloak, Sitzung und API getrennt beobachtet |
| 80-90   | Rücknahme und Auswertung        | Ausgangszustand hergestellt und erklärt             |

## Unterlagen

| Datei oder Verzeichnis          | Inhalt                                                                  |
| ------------------------------- | ----------------------------------------------------------------------- |
| [aufgabe.md](aufgabe.md)        | Teilnehmeraufgabe mit Vorhersagen, Befehlen für Bash und PowerShell     |
| [trainer.md](trainer.md)        | Bereitstellung, Musterlösung, beobachtetes Verhalten, Diagnose, Abbau   |
| [solution/](solution/README.md) | Vollständiger LDAP-Provider per `kcadm`, Umschaltung je Versuch         |
| [lab/](lab/docker-compose.yml)  | Lokaler Stack: Keycloak 26.5.7, PostgreSQL 18, Portal, API, LDAP-Tools  |
| [lab/ldif/](lab/ldif/team01)    | Änderungs- und Rücknahme-LDIFs je Team                                  |
| [scripts/](scripts)             | Bereitstellung, Initialisierung, Prüfung, Reset und Abbau in PowerShell |

Der lokale Stack heißt `keycloak-ad-workshop` und verwendet die Ports 8080, 5173 und 3001.
Laufende Container anderer Labs müssen vorher beendet werden; ein Prune ist nicht nötig.
Die Host-Ports lassen sich über `HOST_PORT_KEYCLOAK`, `HOST_PORT_PORTAL` und `HOST_PORT_API`
verschieben, das Portal erwartet Keycloak dann allerdings weiterhin auf 8080.

## Cloud-Ressourcen und Kosten

`scripts/New-Workshop.ps1` legt im freigegebenen Projekt an: eine Custom-Mode-VPC mit einem
regionalen Subnetz, zwei Firewallregeln (TCP 636 aus den Ausgangs-IPs der Gruppen, TCP 3389 aus
dem IAP-Bereich `35.235.240.0/20`), eine reservierte interne und eine externe IPv4-Adresse, eine
Datendisk 20 GiB, die VM `e2-standard-2` mit Bootdisk 64 GiB (beide pd-balanced) und eine
IAP-Tunnelbindung für den Trainer, begrenzt auf Port 3389. Die VM hat kein Service-Konto.

Listenpreise Frankfurt (`europe-west3`), Cloud Billing Catalog vom 15.09.2026, in USD:

| Posten                                  | Preis                 | Je Stunde |
| --------------------------------------- | --------------------- | --------- |
| E2 vCPU (2)                             | 0,0281 je vCPU-Stunde | 0,056     |
| E2 RAM (8 GiB)                          | 0,0038 je GiB-Stunde  | 0,030     |
| Windows Server 2022 Datacenter (2 vCPU) | 0,046 je vCPU-Stunde  | 0,092     |
| pd-balanced (84 GiB)                    | 0,12 je GiB-Monat     | 0,014     |
| Externe IPv4-Adresse an laufender VM    | 0,005 je Stunde       | 0,005     |
| Summe                                   |                       | 0,197     |

48 Stunden kosten damit rund 9,50 USD, sieben Tage rund 33 USD; ausgehender Datenverkehr für
LDAPS und Windows Update kommt im Cent-Bereich hinzu. Eine gestoppte VM spart nur vCPU, RAM
und Lizenz; Disks und reservierte Adresse laufen weiter. Budgetwarnungen in Cloud Billing
stoppen keine Ausgaben. Der Abbau mit `Remove-Workshop.ps1` beendet alle Posten.

## Betrieb in Kurzform

1. `New-Workshop.ps1 -PlanOnly`, dann ohne `-PlanOnly`: Ressourcen und Manifest unter `.run/`.
2. `gcloud compute start-iap-tunnel kcad-dc01 3389 --local-host-port=localhost:33389`, RDP als `wsadmin`.
3. Im Gast dreimal `Initialize-Domain.ps1` (Umbenennung, Promotion, Nacharbeiten), dann
   Anmeldung als `MUSTERTECH\Administrator` prüfen und `Protect-Workshop.ps1` ausführen.
4. Im Gast `Initialize-Workshop.ps1 -CertificateValidUntil <Datum>`; `workshop-ca.crt`,
   `workshop-ad.json` und die `team<NN>.json` vom DC holen.
5. `Test-Workshop.ps1 -Mode Guest` auf dem DC, `Test-Workshop.ps1 -Mode Trainer -IncludeIap` lokal.
6. Je Team einen Zettel mit IP, CA-Fingerprint und den vier Passwörtern ausgeben.
7. Nach dem Workshop `Remove-Workshop.ps1 -PlanOnly`, dann `Remove-Workshop.ps1`.

Details, Beispielwerte und die im Probelauf beobachteten Ergebnisse stehen in [trainer.md](trainer.md).

## Sicherheitsgrenzen

- Eingehend nur TCP 636 aus den gemeldeten Ausgangs-IPs und TCP 3389 über IAP. Keine Regel aus
  `0.0.0.0/0`; `Test-Workshop.ps1` prüft die effektive Firewall einschließlich Policies.
- TLS- und Hostnamenprüfung bleiben aktiv. Teilnehmer erhalten nur das öffentliche CA-Zertifikat;
  CA-Schlüssel und Serverzertifikat bleiben auf dem DC.
- Bind-Konten lesen nur. Übungskonten dürfen ausschließlich Attribute und Mitgliedschaften der
  eigenen Team-OU ändern; die Prüfskripte testen das negativ gegen das Nachbarteam.
- Passwörter, PFX-Dateien und das Manifest liegen unter `.run/` und `lab/secrets/`, beides
  ignoriert. Im Repository liegen keine Zugangsdaten; die Lab-Passwörter `admin` und `test1234`
  gelten nur lokal.
- Der Abbau löscht ausschließlich Ressourcen aus dem Manifest, geprüft über Labels, Beschreibung
  und selfLink. Das GCP-Projekt und fremde Ressourcen bleiben unberührt.

## Ersatz ohne GCP

Bleibt die Freigabe für Projekt, Netz oder Budget aus, läuft die Einheit mit Lab 07c und dem
[LDAP-Begleitmaterial](../ldap-ad/README.md) in OpenLDAP. Suche, Gruppenänderung und
Rücknahme funktionieren dort gleich. OU-Wechsel mit `objectGUID`, `userAccountControl`,
MSAD-Mapper und die Zertifikatskette gegen einen Windows-DC werden dann anhand der in
[trainer.md](trainer.md) festgehaltenen Ergebnisse besprochen und als Aufzeichnung gekennzeichnet.
