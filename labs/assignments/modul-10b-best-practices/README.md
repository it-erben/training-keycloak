# Modul 10b: Best Practices & Produktion

## Übungsziel

Am Ende dieser Übung hast du:

- Keycloak hinter einem HTTPS-Proxy betrieben und den öffentlichen Issuer geprüft
- Eine Datenbanksicherung zurückgespielt und den wiederhergestellten Stand nachgewiesen
- Einen Datenbankausfall anhand von Login, Readiness und Logs eingegrenzt

## Auftrag: Mustertech bereitet den Betrieb vor

Das Mitarbeiterportal funktioniert. Vor der Übergabe an den Betrieb fehlen drei Themen:
Erreichbarkeit über HTTPS, Wiederherstellung nach einer Fehländerung und Diagnose eines Ausfalls.
Du prüfst diese drei Themen an einer lokalen Testinstallation.

## Voraussetzungen und Start

- Docker Desktop und Docker Compose ab 2.24.4 (`docker compose version`)
- Grundlagen zu Docker und Netzwerken; Modul 10a ist abgeschlossen
- Bash oder PowerShell; unter Windows wird für HTTP-Abfragen ausdrücklich `curl.exe` verwendet

> **Hinweis:** Beende die Container der vorherigen Übung mit `docker compose down -v`
> in deren Verzeichnis. Das löscht deren Lab-Daten. Container-Namen und Volumes werden wiederverwendet;
> Einzelheiten stehen im [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

Wechsle vom Verzeichnis `labs/` nach:

```bash
cd assignments/modul-10b-best-practices
```

Bei einer Wiederholung benenne deine Dateien `docker-compose.override.yml` und
`traefik-dynamic.yml` zunächst um. Sonst lädt Compose die bereits fertige Proxy-Konfiguration.
Ein eventuell gesetztes `COMPOSE_FILE` muss für dieses Lab entfernt sein, damit die automatische
Dateiauswahl greift.

Starte die Basisumgebung. Die folgenden Docker-Befehle gelten für Bash und PowerShell.
Führe sie einzeln aus und halte bei Fehlern an, bevor du den nächsten Befehl startest:

```bash
docker compose up -d --wait --wait-timeout 180 assignment-keycloak assignment-mailpit
docker compose run --rm assignment-setup
docker compose ps
```

Keycloak muss `healthy` sein. Der einmalige Setup-Aufruf muss mit Exitcode 0 enden; er setzt
die lokale SSL-Einstellung im Master-Realm. Prüfe eine Anmeldung an
<http://localhost:8080/realms/mustertech/account/> als `hans.mueller` mit `Muster1234!`.
Die Admin-Konsole unter <http://localhost:8080/admin/> verwendet `admin` / `admin`.
Alle Kennwörter sind ausschließlich Testzugänge.

Für jede neue Anmeldung in dieser Aufgabe schließe zuerst **alle privaten Browserfenster**
und öffne dann ein neues. Zusätzliche private Fenster können dieselbe Sitzung teilen; sonst
prüfst du möglicherweise eine bestehende SSO-Sitzung statt Benutzername und Passwort.

## Teil 1: HTTPS einrichten und prüfen

### Schritt 1.1: Den Weg einer Anfrage erklären

Der Browser soll Keycloak über `https://keycloak.localhost:8443` erreichen. Traefik nimmt
HTTPS an und leitet die Anfrage im Docker-Netz über HTTP an Keycloak weiter:

```text
Browser -- HTTPS :8443 --> Traefik -- HTTP :8080 --> Keycloak --> PostgreSQL
                                                    |
                                       Management :9000 nur lokal
```

Beantworte, bevor du die Konfiguration anlegst:

1. An welcher Stelle endet TLS?
2. Welche URL muss im `issuer` stehen: die öffentliche Adresse oder der interne Containername?
3. Warum darf der Browser den internen HTTP-Port nach der Umstellung nicht direkt erreichen?

### Schritt 1.2: Proxy und Produktionsmodus konfigurieren

Erstelle `docker-compose.override.yml` im Lab-Verzeichnis. Compose lädt diese Datei bei
jedem `docker compose`-Aufruf automatisch zusätzlich zur Basisdatei.

```yaml
services:
  traefik:
    image: traefik:v3.0
    container_name: assignment-traefik
    command:
      - "--providers.file.filename=/etc/traefik/dynamic.yml"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "127.0.0.1:8443:443"
    volumes:
      - ./traefik-dynamic.yml:/etc/traefik/dynamic.yml:ro
    networks:
      - assignment-network

  assignment-keycloak:
    command: start --import-realm
    ports: !override
      - "127.0.0.1:9000:9000"
    environment:
      KC_HOSTNAME: https://keycloak.localhost:8443
      KC_HOSTNAME_STRICT: "true"
```

**Ergänze unter `environment` zwei Einstellungen:** Keycloak soll intern HTTP annehmen
(`KC_HTTP_ENABLED`), und es soll die vom Proxy gesetzten `X-Forwarded-*`-Header auswerten
(`KC_PROXY_HEADERS`). Leite die Werte aus dem Anfrageweg ab; bei Bedarf hilft die
[Keycloak-Dokumentation zum Reverse Proxy](https://www.keycloak.org/server/reverseproxy).

`!override` ersetzt die Portliste der Basisdatei. Dadurch entfällt die bisherige Freigabe von
8080; der Management-Port bleibt an die lokale Loopback-Adresse gebunden.

Erstelle daneben `traefik-dynamic.yml`:

```yaml
http:
  routers:
    keycloak:
      rule: "Host(`keycloak.localhost`)"
      entryPoints:
        - websecure
      service: keycloak
      tls: {}
  services:
    keycloak:
      loadBalancer:
        servers:
          - url: "http://assignment-keycloak:8080"
```

Prüfe die zusammengeführte Konfiguration, indem du den Stack startest:

```bash
docker compose config --quiet
docker compose up -d --wait --wait-timeout 180 assignment-keycloak traefik
docker compose ps
```

Bei einem Fehler prüfe `docker compose logs --tail 50 assignment-keycloak traefik`.
Die Installation bleibt für den Rest der Übung in dieser HTTPS-Konfiguration.

### Schritt 1.3: HTTPS, Issuer und Login testen

Öffne <https://keycloak.localhost:8443/admin/>. Traefik liefert ein selbstsigniertes
Standardzertifikat. Bestätige die Ausnahme nur für dieses lokale Lab.
Falls der Name nicht aufgelöst wird, ergänze `127.0.0.1 keycloak.localhost` in `/etc/hosts`
(Linux/macOS) oder `C:\Windows\System32\drivers\etc\hosts` (Windows, Administratorrechte nötig).

Frage die Discovery ab. `--insecure` überbrückt hier nur die Prüfung des Testzertifikats.
`--resolve` setzt für diese einzelne Anfrage die Adresse des Testservers:

**Bash:**

```bash
curl --fail --insecure --resolve keycloak.localhost:8443:127.0.0.1 https://keycloak.localhost:8443/realms/mustertech/.well-known/openid-configuration
```

**PowerShell:**

```powershell
curl.exe --fail --insecure --resolve keycloak.localhost:8443:127.0.0.1 https://keycloak.localhost:8443/realms/mustertech/.well-known/openid-configuration
```

Schau dir `issuer` und `authorization_endpoint` an und prüfe, ob du diese Werte erwartest hast. Melde dich anschließend
in einem frischen privaten Browserfenster unter
<https://keycloak.localhost:8443/realms/mustertech/account/> als Hans an.
Prüfe mit `docker compose ps`, dass kein Host-Port 8080 mehr für Keycloak veröffentlicht wird.

Notiere den Issuer und das Login-Ergebnis. Erkläre außerdem, welcher Schutz durch
die Zertifikatsausnahme bei diesem Test nicht geprüft wird.

## Teil 2: Ein Backup wiederherstellen

### Schritt 2.1: Sicherungsumfang beurteilen

Öffne in der Admin-Konsole **Realm settings** -> **Action** -> **Partial export**.
Exportiere Gruppen/Rollen und Clients. Suche im JSON nach dem regulären Benutzer `hans.mueller`.
Service-Account-Benutzer können im Partial Export enthalten sein.

Entscheide: Reicht diese Datei, um die aktuelle Installation einschließlich Benutzerkonten und
Kennwörtern wiederherzustellen? Für den folgenden Versuch sicherst du die PostgreSQL-Datenbank.

### Schritt 2.2: Datenbank sichern

Lege das Verzeichnis `backup` an.

**Bash:**

```bash
mkdir -p backup
```

**PowerShell:**

```powershell
New-Item -ItemType Directory -Force backup
```

Stoppe Keycloak für die Sicherung. Traefik und PostgreSQL bleiben aktiv. Der Dump wird im
Container geschrieben und anschließend kopiert; so verändert keine Shell-Umleitung sein Binärformat.

```bash
docker compose stop assignment-keycloak
docker compose exec -T assignment-postgres pg_dump -U keycloak -Fc -f /tmp/keycloak.dump keycloak
docker compose cp assignment-postgres:/tmp/keycloak.dump backup/keycloak.dump
docker compose exec -T assignment-postgres pg_restore --list /tmp/keycloak.dump
docker compose up -d --wait --wait-timeout 180 assignment-keycloak
```

Fahre nur fort, wenn Dump und Inhaltsverzeichnis ohne Fehler enden. Das Inhaltsverzeichnis
belegt die Lesbarkeit des Archivs; die Wiederherstellung prüfst du erst im nächsten Schritt.
Der Dump enthält sensible Daten. `backup/` ist von Git ausgeschlossen.

### Schritt 2.3: Eine Änderung bewusst zurücknehmen

Lege **nach** der Sicherung im Realm `mustertech` einen Benutzer `restore-probe` an.
Aktualisiere die Benutzerliste und bestätige, dass er existiert.

Notiere vor der Wiederherstellung:

- Muss `restore-probe` danach noch vorhanden sein?
- Was erwartest du für Hans und sein Passwort?
- Welche Änderungen seit der Sicherung gehen ebenfalls verloren?

**Die folgenden Befehle ersetzen die Daten dieses Labs durch den Sicherungsstand.** Keycloak
bleibt während des Restore gestoppt, damit es keine Änderungen schreibt oder alte Cache-Inhalte nutzt.

```bash
docker compose stop assignment-keycloak
docker compose cp backup/keycloak.dump assignment-postgres:/tmp/keycloak.dump
docker compose exec -T assignment-postgres pg_restore -U keycloak -d keycloak --clean --if-exists --exit-on-error /tmp/keycloak.dump
```

Bei einem Restore-Fehler stoppe die Befehlsfolge und prüfe die Ausgabe. Ein neuer Start ist erst
nach einem erfolgreichen Restore sinnvoll. In PowerShell zeigt `$LASTEXITCODE`, in Bash `$?`
unmittelbar nach dem Befehl dessen Exitcode; erfolgreich ist `0`. Starte danach Keycloak:

```bash
docker compose up -d --wait --wait-timeout 180 assignment-keycloak
```

Prüfe Realm und Clients, suche `restore-probe` und melde Hans in einem frischen
privaten Fenster über HTTPS an. Erst diese Gegenprobe zeigt, ob der erwartete Stand wieder nutzbar ist.

Überlege zum Abschluss, welche Dateien außerhalb der Datenbank für diesen Aufbau ebenfalls
benötigt werden. Woran scheitert ein Restore, wenn zwar der Dump vorhanden ist, aber die passende
Keycloak-Version oder die Proxy-Konfiguration fehlt?

## Teil 3: Einen Datenbankausfall untersuchen

### Schritt 3.1: Vor dem Stoppen

Lies Liveness, Readiness und Metriken vom lokalen Management-Port. `-i` zeigt zusätzlich den
HTTP-Status. Für die Diagnose verwenden wir kein `--fail`, damit auch die Antwort bei HTTP 503
sichtbar bleibt.

**Bash:**

```bash
curl -i --max-time 20 http://localhost:9000/health/live
curl -i --max-time 20 http://localhost:9000/health/ready
curl --fail --max-time 20 http://localhost:9000/metrics
```

**PowerShell:**

```powershell
curl.exe -i --max-time 20 http://localhost:9000/health/live
curl.exe -i --max-time 20 http://localhost:9000/health/ready
curl.exe --fail --max-time 20 http://localhost:9000/metrics
```

Merke dir die HTTP-Statuscodes und suche in der Readiness-Antwort nach dem Datenbankcheck.
Health und Metrics sind in der Basisdatei bereits aktiviert. Suche außerdem eine JVM-Metrik
und notiere ihren Namen samt Wert; damit ist noch keine Alarmierung eingerichtet.

### Schritt 3.2: Datenbank stoppen

Keycloak und Traefik bleiben eingeschaltet. Was erwartest du für Liveness, Readiness und eine
**neue** Benutzeranmeldung, wenn PostgreSQL ausfällt? Reicht es zur Diagnose, eine bereits
geöffnete Seite anzusehen?

Stoppe ausschließlich die Datenbank dieses Labs:

```bash
docker compose stop assignment-postgres
```

Wiederhole die beiden Health-Abfragen aus Schritt 3.1. Der Pool muss defekte Verbindungen erst
erkennen; frage bei unverändertem Ergebnis nach einigen Sekunden erneut ab.
Versuche in einem frischen privaten Fenster einen neuen Login als Hans. Notiere auch Wartezeit
oder Fehlermeldung, statt nur auf die Darstellung der Login-Seite zu achten.

Sieh in die Logs und den Containerstatus:

```bash
docker compose logs --since 2m --tail 80 assignment-keycloak
docker compose ps -a
```

Ordne deine Befunde den drei Stationen Proxy, Keycloak und Datenbank zu. Würde ein Neustart
von Keycloak die Ursache beheben? Begründe deine Antwort mit einer Logzeile oder einem Health-Check.

### Schritt 3.3: Wiederanlauf prüfen

Starte die Datenbank wieder, auch wenn du den Versuch vorzeitig abbrichst:

```bash
docker compose up -d --wait --wait-timeout 180 assignment-postgres
```

Wiederhole die Readiness-Abfrage, bis sie wieder HTTP 200 liefert. Prüfe dann einen frischen
HTTPS-Login als Hans. Falls Keycloak nach einer Minute noch keine Verbindung bekommt, sichere
zuerst die Logs und starte anschließend nur diesen Dienst neu:

```bash
docker compose restart assignment-keycloak
```

## Zusatz: CLI-Export mit Benutzerkonfiguration

Vergleiche bei verbleibender Zeit den Partial Export mit dem CLI-Export. Stoppe dafür Keycloak;
der Export startet einen eigenen Prozess mit derselben Datenbankkonfiguration.
Die HTTPS- und Proxy-Dateien bleiben unverändert.

```bash
docker compose stop assignment-keycloak
docker compose run --name assignment-export --no-deps assignment-keycloak export --dir /tmp/realm-export --realm mustertech
```

Prüfe den Exitcode des Exports. Kopiere die Dateien nur nach erfolgreichem Abschluss:

```bash
docker cp assignment-export:/tmp/realm-export/. backup/
docker rm assignment-export
docker compose up -d --wait --wait-timeout 180 assignment-keycloak
```

In `mustertech-realm.json`
stehen unter anderem Clients, Rollen und Gruppen; `mustertech-users-0.json` enthält reguläre
Benutzer und deren Credential-Daten. Behandle diese Dateien entsprechend vertraulich.
Vergleiche den Inhalt mit dem Partial Export. Laufende Sitzungen und Event-Historie werden
vom CLI-Export nicht gesichert.

## Aufräumen

Nach Abschluss der Übung:

```bash
docker compose down -v
```

Das entfernt auch Traefik und die Datenbank dieses Labs. Die selbst erstellten Proxy-Dateien
und `backup/` bleiben auf dem Rechner; sie werden nicht versioniert. Entferne nicht mehr
benötigte Sicherungen nach dem Kurs.

## Quellen und Trainerunterlage

- [Keycloak: Reverse Proxy](https://www.keycloak.org/server/reverseproxy)
- [Keycloak: Import und Export](https://www.keycloak.org/server/importExport)
- [Keycloak: Health Checks](https://www.keycloak.org/observability/health)
- [Trainerlösung und Auswertung](trainer.md)
