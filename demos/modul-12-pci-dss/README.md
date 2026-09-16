# Live-Demo Modul 12: Keycloak und PCI DSS

Ein automatisiertes Audit gegen den Lab-Stack, einmal vor dem Lab mit roten Zeilen, einmal
danach mit grünen. Die Prüfung läuft als Skript gegen die Admin-API.

| Demo   | Thema                                 |
| :----- | :------------------------------------ |
| Demo 1 | Audit-Skript vor dem Lab              |
| Demo 2 | Eine Prüfung im Skript nachvollziehen |
| Demo 3 | Audit-Skript nach dem Lab             |
| Demo 4 | Admin Events als Nachweis             |

## Voraussetzungen

- Docker / Podman (Container-Runtime)
- Bash und `python3` auf dem Host; unter Windows Ubuntu mit Docker-Integration nach der
  [Windows-Einrichtung](../../labs/WINDOWS.md)
- Lab 12 gestartet (`docker compose up -d` in `labs/assignments/modul-12-pci-dss`)

## Setup

```bash
cd demos/modul-12-pci-dss
chmod +x audit.sh
```

Das Skript holt bei jedem Start einen frischen Admin-Token und liest beide Realms
über `kcadm.sh --no-config --token` im Container `assignment-keycloak`. Vor der
OTP-Einrichtung reicht `./audit.sh`; danach liest `./audit.sh --otp` den aktuellen
Code verdeckt ein. Passwort und OTP werden gemeinsam an den Token-Endpunkt gesendet.
Eine fehlgeschlagene Anmeldung beendet das Skript mit Exit-Code 2; fehlgeschlagene
Audit-Prüfungen liefern Exit-Code 1.

Für abweichende Lab-Adressen gibt es `KEYCLOAK_URL` (vom Host erreichbar),
`KCADM_SERVER` (im Container erreichbar), `CONTAINER` und `REALM`. Die Lab-Vorgaben
für `ADMIN_USER` und `ADMIN_PASSWORD` sind jeweils `admin`. Automatisierte Aufrufe
können `ADMIN_OTP` setzen; ein OTP-Code darf nicht wiederverwendet werden.

---

## Demo 1: Audit-Skript vor dem Lab

### Schritt 1: Skript ausführen

```bash
./audit.sh
```

### Schritt 2: Ergebnis lesen

Die meisten der vierzehn Zeilen sind rot. Auf die Spalte rechts zeigen: sie nennt den Ist-Wert, den das
Skript aus dem Realm gelesen hat, etwa `length(10)` oder `5 Versuche`.

Der Realm aus Modul 10 ist abgesichert, aber nicht PCI-konform. Die Abweichungen liegen in den
Grenzwerten.

---

## Demo 2: Eine Prüfung im Skript nachvollziehen

### Schritt 1: Rohdaten zeigen

```bash
TOKEN=$(./audit.sh --token)
docker exec -i assignment-keycloak /opt/keycloak/bin/kcadm.sh get realms/mustertech \
  --no-config --server http://localhost:8080 --realm master --token "$TOKEN" \
  | grep -E "passwordPolicy|failureFactor|waitIncrementSeconds|ssoSessionIdleTimeout|eventsExpiration"
```

### Schritt 2: Zuordnung erklären

Auf `passwordPolicy` zeigen: derselbe String, der in der Admin-Konsole als Liste erscheint. Das
Skript liest `length(…)` und `passwordHistory(…)` per Regex heraus und vergleicht mit 12 und 4.

Jede Einstellung der Admin-Konsole ist ein Feld in der Admin-API. Was ein QSA fragt, lässt sich
als Abfrage formulieren.

---

## Demo 3: Audit-Skript nach dem Lab

### Schritt 1: Erneut ausführen

```bash
./audit.sh --otp
```

Alle Zeilen grün, Exit-Code 0. Bei einer übersprungenen Lab-Aufgabe bleibt die Zeile rot und
zeigt, welche.

Das Skript gehört in die CI der Realm-Konfiguration. Ein Merge, der einen Wert unter die Grenze
zieht, bricht den Build.

---

## Demo 4: Admin Events als Nachweis

### Schritt 1: Passwort-Reset des Helpdesks finden

```bash
TOKEN=$(./audit.sh --otp --token)
docker exec -i assignment-keycloak /opt/keycloak/bin/kcadm.sh get admin-events \
  --no-config --server http://localhost:8080 --realm master --token "$TOKEN" \
  -r mustertech -q operationTypes=ACTION -q resourcePath=users/*/reset-password
```

### Schritt 2: Felder zeigen

Auf `authDetails.userId`, `time`, `operationType` und `resourcePath` zeigen. Dann
`userId` gegen `tom.helpdesk` auflösen:

```bash
docker exec -i assignment-keycloak /opt/keycloak/bin/kcadm.sh get users/<userId> \
  --no-config --server http://localhost:8080 --realm master --token "$TOKEN" \
  -r mustertech --fields username
unset TOKEN
```

Der Event belegt, wer wann das Credential welches Benutzers geändert hat. Der
Passwort-Reset enthält auch bei aktiviertem `Include representation` keine
`representation`. Das Passwort gehört nicht in die protokollierten Request-Daten.

---

## Aufräumen

Nichts zu tun; das Skript verändert den Realm nicht. Der Lab-Stack läuft weiter.
