# Workshop: Keycloak an Active Directory auf GCP

Jede teilnehmende Person verbindet ihr lokales Keycloak per LDAPS mit einem eigenen,
vorbereiteten Active Directory und verfolgt Änderungen im Verzeichnis bis zur Portal-API.
Jedes Verzeichnis läuft als eigener Windows Server 2022 mit AD DS auf Google Compute Engine;
der Trainer stellt die Server vor dem Kurs bereit, stoppt sie über Nacht, startet sie am Morgen
und baut sie danach ab. Die 90 Minuten enthalten keine Cloud-Bereitstellung.

Voraussetzungen der Teilnehmer: Modul 06b (Portal und Portal-API), Modul 07 mit Lab 07c
(LDAP-Provider, Group-Mapper) und Docker Compose. Voraussetzungen des Trainers: PowerShell 7,
gcloud CLI, OpenSSH-Client, Docker und ein GCP-Projekt mit aktivierter Compute Engine API und IAP API.

## Ablauf

| Minuten | Aufgabe                         | Nachweis                                            |
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
| [solution/](solution/README.md) | Vollständiger LDAP-Provider per `kcadm`, Umschaltung je Aufgabe         |
| [lab/](lab/docker-compose.yml)  | Lokaler Stack: Keycloak 26.5.7, PostgreSQL 18, Portal, API, LDAP-Tools  |
| [lab/ldif/](lab/ldif)           | Änderungs- und Rücknahme-LDIFs für die sechs Aufgaben                   |
| [scripts/](scripts)             | Bereitstellung, Initialisierung, Prüfung, Reset und Abbau in PowerShell |

Der lokale Stack heißt `keycloak-ad-workshop` und verwendet die Ports 8080, 5173 und 3001.
Laufende Container anderer Labs müssen vorher beendet werden; ein Prune ist nicht nötig.
Die Host-Ports lassen sich über `HOST_PORT_KEYCLOAK`, `HOST_PORT_PORTAL` und `HOST_PORT_API`
verschieben, das Portal erwartet Keycloak dann allerdings weiterhin auf 8080.

## Cloud-Ressourcen und Kosten

`scripts/Invoke-WorkshopFleet.ps1 -Action Deploy -Count 5` legt je Person eine eigene Umgebung an
(Präfixe `kcad1` bis `kcad5`): eine Custom-Mode-VPC mit regionalem Subnetz, Firewallregeln (TCP 636 aus
der Ausgangs-IP des Schulungsraums, TCP 3389 und 22 aus dem IAP-Bereich `35.235.240.0/20`), eine
reservierte interne und eine externe IPv4-Adresse, eine Datendisk 20 GiB, die VM `e2-standard-2` mit
Bootdisk 64 GiB (beide pd-balanced) und eine IAP-Tunnelbindung für den Trainer. Die VMs haben kein
Service-Konto. Jede Umgebung hat ein eigenes Manifest unter `.run/<präfix>/`. Neue Projekte erlauben fünf
VPC-Netze; für fünf Umgebungen muss das ungenutzte `default`-Netz gelöscht oder das Quota `NETWORKS`
erhöht sein. `New-Workshop.ps1` prüft das vor dem Anlegen.

Listenpreise Frankfurt (`europe-west3`), Cloud Billing Catalog vom 15.09.2026, in USD je VM:

| Posten                                  | Preis                 | Je Stunde |
| --------------------------------------- | --------------------- | --------- |
| E2 vCPU (2)                             | 0,0281 je vCPU-Stunde | 0,056     |
| E2 RAM (8 GiB)                          | 0,0038 je GiB-Stunde  | 0,030     |
| Windows Server 2022 Datacenter (2 vCPU) | 0,046 je vCPU-Stunde  | 0,092     |
| pd-balanced (84 GiB)                    | 0,12 je GiB-Monat     | 0,014     |
| Externe IPv4-Adresse an laufender VM    | 0,005 je Stunde       | 0,005     |
| Summe                                   |                       | 0,197     |

Fünf laufende VMs kosten rund 1 USD je Stunde, ein Kurstag mit acht Stunden rund 8 USD. Eine gestoppte
VM spart vCPU, RAM und Lizenz; Disks und reservierte Adresse laufen weiter, rund 0,02 USD je Stunde und
VM. Budgetwarnungen in Cloud Billing stoppen keine Ausgaben. Der Abbau mit `-Action Remove` beendet alle Posten.

## Betrieb in Kurzform

Alle Befehle aus `workshops/active-directory/scripts` in PowerShell 7 mit angemeldetem gcloud:

1. `./Invoke-WorkshopFleet.ps1 -Action Deploy -Count 5 -ProjectId <projekt> -LdapsSourceRanges <cidr>
   -TrainerPrincipal user:<mail> -PlanOnly`, dann ohne `-PlanOnly`. Das Skript legt die Umgebungen an,
   richtet die Domänen parallel über SSH per IAP ein und prüft jede Umgebung. Rund 60 bis 90 Minuten.
2. `-Action Packages` zeigt je Person IP, CA-Datei, Fingerprint und die vier Passwörter zur Weitergabe.
3. Am Vorabend `-Action Stop`, am Kursmorgen `-Action Start`; Start wartet auf LDAPS und prüft erneut.
4. Nach dem Kurs `-Action Remove -PlanOnly`, dann `-Action Remove`.

Details, Beispielwerte, der RDP-Weg für einzelne Umgebungen und die im Probelauf beobachteten
Ergebnisse stehen in [trainer.md](trainer.md).

## Sicherheitsgrenzen

- Eingehend nur TCP 636 aus den gemeldeten Ausgangs-IPs sowie TCP 3389 und 22 über IAP für den
  Trainer. Keine Regel aus `0.0.0.0/0`; `Test-Workshop.ps1` prüft die effektive Firewall einschließlich Policies.
- TLS- und Hostnamenprüfung bleiben aktiv. Teilnehmer erhalten nur das öffentliche CA-Zertifikat;
  CA-Schlüssel und Serverzertifikat bleiben auf dem DC.
- Das Bind-Konto liest nur. Das Übungskonto darf ausschließlich Attribute und Mitgliedschaften in
  `OU=Workshop` ändern; die Prüfskripte testen das negativ gegen Dienstkonten und Domänen-Admin.
- Passwörter, Manifeste und CA-Dateien liegen unter `.run/<präfix>/` und `lab/secrets/`, beides
  ignoriert. Im Repository liegen keine Zugangsdaten; die Lab-Passwörter `admin` und `test1234`
  gelten nur lokal.
- Der Abbau löscht ausschließlich Ressourcen aus den Manifesten, geprüft über Labels, Beschreibung
  und selfLink. Das GCP-Projekt und fremde Ressourcen bleiben unberührt.

## Ersatz ohne GCP

Bleibt die Freigabe für Projekt, Netz oder Budget aus, läuft die Einheit mit Lab 07c und dem
[LDAP-Begleitmaterial](../ldap-ad/README.md) in OpenLDAP. Suche, Gruppenänderung und
Rücknahme funktionieren dort gleich. OU-Wechsel mit `objectGUID`, `userAccountControl`,
MSAD-Mapper und die Zertifikatskette gegen einen Windows-DC werden dann anhand der in
[trainer.md](trainer.md) festgehaltenen Ergebnisse besprochen und als Aufzeichnung gekennzeichnet.
