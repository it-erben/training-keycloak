# Live-Demo: Modul 12 -- Keycloak und PCI DSS

Ein automatisiertes Audit gegen den Lab-Stack -- einmal vor dem Lab mit roten Zeilen, einmal
danach mit grünen. Zeigt, dass Compliance-Prüfung ein Skript sein kann, kein Klickprotokoll.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Audit-Skript vor dem Lab | 3 Min |
| Demo 2 | Eine Prüfung im Skript nachvollziehen | 3 Min |
| Demo 3 | Audit-Skript nach dem Lab | 2 Min |
| Demo 4 | Admin Events als Nachweis | 3 Min |

## Voraussetzungen

- Docker / Podman (Container-Runtime)
- `python3` auf dem Host
- Lab 12 gestartet (`docker compose up -d` in `labs/assignments/modul-12-pci-dss`)

## Setup

```bash
cd demos/modul-12-pci-dss
chmod +x audit.sh
```

Das Skript liest den Realm `mustertech` und den Realm `master` über `kcadm.sh` im Container
`assignment-keycloak`. Sobald der Admin ein OTP hat (Lab Teil 5.3), fragt `kcadm.sh` beim
Start nach dem Code.

---

## Demo 1: Audit-Skript vor dem Lab

### Schritt 1 -- Skript ausführen

```bash
./audit.sh
```

### Schritt 2 -- Ergebnis lesen

Die meisten der vierzehn Zeilen sind rot. Auf die Spalte rechts zeigen: sie nennt den Ist-Wert, den das
Skript aus dem Realm gelesen hat, etwa `length(10)` oder `5 Versuche`.

Kernaussage: Der Realm aus Modul 10 ist abgesichert, aber nicht PCI-konform. Der Unterschied
sind Zahlen, keine Konzepte.

---

## Demo 2: Eine Prüfung im Skript nachvollziehen

### Schritt 1 -- Rohdaten zeigen

```bash
docker exec -i assignment-keycloak /opt/keycloak/bin/kcadm.sh get realms/mustertech \
  | grep -E "passwordPolicy|failureFactor|waitIncrementSeconds|ssoSessionIdleTimeout|eventsExpiration"
```

### Schritt 2 -- Zuordnung erklären

Auf `passwordPolicy` zeigen: derselbe String, der in der Admin-Konsole als Liste erscheint. Das
Skript liest `length(…)` und `passwordHistory(…)` per Regex heraus und vergleicht mit 12 und 4.

Kernaussage: Jede Einstellung der Admin-Konsole ist ein Feld in der Admin-API. Was ein QSA
fragt, lässt sich als Abfrage formulieren.

---

## Demo 3: Audit-Skript nach dem Lab

### Schritt 1 -- Erneut ausführen

```bash
./audit.sh
```

Alle Zeilen grün, Exit-Code 0. Bei einer übersprungenen Lab-Aufgabe bleibt die Zeile rot und
zeigt, welche.

Kernaussage: Das Skript gehört in die CI der Realm-Konfiguration. Ein Merge, der einen Wert
unter die Grenze zieht, bricht den Build.

---

## Demo 4: Admin Events als Nachweis

### Schritt 1 -- Passwort-Reset des Helpdesks finden

```bash
docker exec -i assignment-keycloak /opt/keycloak/bin/kcadm.sh get admin-events \
  -r mustertech -q operationTypes=ACTION -q resourcePath=users/*/reset-password
```

### Schritt 2 -- Felder zeigen

Auf `authDetails.userId`, `time`, `resourcePath` und `representation` zeigen. Dann den
`userId` gegen `tom.helpdesk` auflösen:

```bash
docker exec -i assignment-keycloak /opt/keycloak/bin/kcadm.sh get users/<userId> \
  -r mustertech --fields username
```

Kernaussage: Anforderung 10.2.1 verlangt genau diesen Nachweis: wer hat wann welches Credential
geändert. Ohne `Include representation` fehlt das Was.

---

## Aufräumen

Nichts zu tun; das Skript verändert den Realm nicht. Der Lab-Stack läuft weiter.
