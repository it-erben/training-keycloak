# Keycloak-Schulung

Kursunterlagen für eine Keycloak-Schulung mit zwölf Modulen, 17 Übungen und Vorführungen für den
Trainer. Der Kurs beginnt bei Identity and Access Management (IAM), behandelt die Anmeldung von
Anwendungen mit OpenID Connect und führt bis zum Betrieb von Keycloak auf Kubernetes.

Die Übungen bauen auf dem Mitarbeiterportal der fiktiven Mustertech GmbH auf. Im Verlauf des Kurses
kommen Benutzer und Rollen, eine React-Anwendung, eine API und weitere Clients hinzu. So lässt sich
am selben Beispiel nachvollziehen, wie Anmeldung, Berechtigungen und Logout zusammenspielen.

## Einstieg in die Übungen

Für die Compose-Labs werden Docker Desktop mit Docker Compose, ein Browser mit Entwicklerwerkzeugen
und ein Code-Editor benötigt. Die Compose-Dateien verwenden Keycloak 26.5 und PostgreSQL 18.
Zusätzliche Werkzeuge stehen in der jeweiligen Lab-Anleitung.

Die [Windows-Einrichtung](labs/WINDOWS.md) beschreibt WSL 2, die Docker-Integration und
die Wahl der Shell für die Bash-Skripte und das Kubernetes-Lab.

Die erste praktische Übung ist [Modul 03: Installation][03]. Start aus dem Hauptverzeichnis des
Repositories:

```bash
cd labs/assignments/modul-03-installation
docker compose up -d
docker compose ps -a
```

Die Umgebung ist bereit, wenn `assignment-keycloak` und `assignment-postgres` als `healthy`
angezeigt werden und `assignment-setup` mit `Exited (0)` beendet ist. Der Setup-Container läuft nur
einmal. Bei einem verzögerten Start zeigen die Logs, woran Keycloak gerade arbeitet:

```bash
docker compose logs -f assignment-keycloak
```

Die [Admin-Konsole](http://localhost:8080/admin/) ist anschließend mit `admin` als Benutzername und
Passwort erreichbar. In Modul 03 entsteht der erste Realm von Hand. Die weiteren Übungen bringen
den benötigten Ausgangszustand als Realm-Import mit, sodass auch ein Einstieg in ein späteres Modul
möglich ist.

Die Compose-Umgebungen sind für lokale Übungen eingerichtet. Keycloak läuft dort mit `start-dev`
und festen Übungszugangsdaten.

### Zwischen Labs wechseln

Die Labs teilen sich Container-Namen und Ports. Vor dem nächsten Lab wird die bisherige Umgebung
im zugehörigen Lab-Verzeichnis beendet:

```bash
docker compose down -v
```

`-v` löscht auch die Datenbank-Volumes einschließlich aller Änderungen aus der Übung. Dadurch startet
das nächste Lab mit dem vorgesehenen Realm-Zustand. Die `cd`-Befehle innerhalb der Lab-Anleitungen
gehen vom Verzeichnis `labs/` aus.

[Modul 11][11] verwendet minikube. Dafür sind zusätzlich `kubectl`, `openssl`, vier CPUs und 6 GB RAM
für den Cluster vorgesehen. Start, Realm-Import und Abbau mit `minikube delete` stehen in der
Lab-Anleitung.

## Module

Die Themen verlinken auf die Folien, die Übungsnummern auf die jeweiligen Anleitungen.
Bei den Modulen 06, 07, 09 und 10 verteilen sich die praktischen Aufgaben auf mehrere Labs.

| Modul | Thema und Folien                                             | Übungen                    |
| :---- | :----------------------------------------------------------- | :------------------------- |
| 01    | [Einführung in IAM und Keycloak][folien-01]                  | Keine eigene Übung         |
| 02    | [Protokoll-Standards: OAuth 2.0, OIDC und SAML][folien-02]   | Keine eigene Übung         |
| 03    | [Installation und Grundkonfiguration][folien-03]             | [03]                       |
| 04    | [Clients und Benutzerverwaltung][folien-04]                  | [04]                       |
| 05    | [Authentifizierung und MFA][folien-05]                       | [05]                       |
| 06    | [SSO, Sessions und Tokens][folien-06]                        | [06a], [06b], [06c], [06d] |
| 07    | [Identity Provider und Föderation][folien-07]                | [07], [07b], [07c]         |
| 08    | [Zugriffskontrolle und Authorization Services][folien-08]    | [08]                       |
| 09    | [Theming, APIs und SPIs][folien-09]                          | [09a], [09b]               |
| 10    | [Betrieb, Sicherheit und Best Practices][folien-10]          | [10a], [10b]               |
| 11    | [Keycloak auf Kubernetes][folien-11]                         | [11]                       |
| 12    | [Keycloak und PCI DSS][folien-12]                            | [12]                       |

## Materialien im Repository

- [`slides/`](slides/) enthält die zwölf Foliendecks als Marp-Markdown. Die CI baut daraus PDFs.
  Der GitHub-Workflow veröffentlicht die PDFs bei einem neuen Release über GitHub Pages.
- [`labs/assignments/`](labs/assignments/) enthält die Übungen mit Compose-Dateien, Realm-Imports
  und Screenshots. Für das Kubernetes-Lab liegen die Ressourcen unter
  [`modul-11-kubernetes/manifests/`](labs/assignments/modul-11-kubernetes/manifests/).
- [`workshops/`](workshops/) enthält zwei ergänzende Architektur- und Betriebsworkshops mit Kurzfolien,
  Aufgabenblättern und separaten Trainerunterlagen für jeweils 60 Minuten.
- [`demos/`](demos/) enthält die Vorführungen für den Trainer, jeweils mit eigener Anleitung.
- [`materials/`](materials/) enthält Vorlagen für Kurzvorträge zum
  [Client Credentials Flow](materials/oauth2-client-credentials-flow.md) und zum
  [Device Authorization Flow](materials/oauth2-device-flow.md).

Der gemeinsame Anwendungscode liegt unter [`labs/assignments/services/`](labs/assignments/services/).
Das React-Frontend meldet Benutzer über OIDC mit PKCE an; die Express-API prüft die Access Tokens.
Der Sync-Service nutzt Client Credentials, während die Management-CLI den Device Flow verwendet.
Auch das Mustertech-Theme für Keycloak liegt dort.

## Hilfe und Änderungen

Fehlerbilder zu Container-Namen, belegten Ports, Realm-Imports und minikube stehen im
[Troubleshooting](labs/assignments/TROUBLESHOOTING.md). Die einzelnen Lab-Anleitungen beschreiben
die fachlichen Schritte und die erwarteten Ergebnisse.

Nach Änderungen prüft `pre-commit run --all-files` Markdown, YAML und Links. Änderungen an einer
Übung werden zusätzlich in der laufenden Lab-Umgebung geprüft.

Die Folien tragen den Lizenzhinweis `CC BY-NC-SA 4.0, Alexander Erben`.

[folien-01]: slides/01-einfuehrung-keycloak-iam/slides.md
[folien-02]: slides/02-protokoll-standards/slides.md
[folien-03]: slides/03-installation-grundkonfiguration/slides.md
[folien-04]: slides/04-clients-benutzerverwaltung/slides.md
[folien-05]: slides/05-authentifizierung-mfa/slides.md
[folien-06]: slides/06-sso-sessions-tokens/slides.md
[folien-07]: slides/07-identity-provider-foederation/slides.md
[folien-08]: slides/08-zugriffskontrolle-authorization/slides.md
[folien-09]: slides/09-anpassung-theming-apis/slides.md
[folien-10]: slides/10-betrieb-sicherheit-best-practices/slides.md
[folien-11]: slides/11-keycloak-kubernetes/slides.md
[folien-12]: slides/12-pci-dss/slides.md
[03]: labs/assignments/modul-03-installation/README.md
[04]: labs/assignments/modul-04-benutzerverwaltung/README.md
[05]: labs/assignments/modul-05-authentifizierung-mfa/README.md
[06a]: labs/assignments/modul-06a-sso-portal/README.md
[06b]: labs/assignments/modul-06b-client-management/README.md
[06c]: labs/assignments/modul-06c-gitea-oidc/README.md
[06d]: labs/assignments/modul-06d-logout/README.md
[07]: labs/assignments/modul-07-identity-provider/README.md
[07b]: labs/assignments/modul-07b-github-idp/README.md
[07c]: labs/assignments/modul-07c-ldap-federation/README.md
[08]: labs/assignments/modul-08-authorization/README.md
[09a]: labs/assignments/modul-09a-anpassung-theming/README.md
[09b]: labs/assignments/modul-09b-anpassung-apis/README.md
[10a]: labs/assignments/modul-10a-sicherheit/README.md
[10b]: labs/assignments/modul-10b-best-practices/README.md
[11]: labs/assignments/modul-11-kubernetes/README.md
[12]: labs/assignments/modul-12-pci-dss/README.md
