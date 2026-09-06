# Zentrales Troubleshooting

Diese Seite gilt fuer alle Module unter `assignments/modul-*`.

## Container-Name-Konflikt

**Symptom:** Beim Start erscheint ein Fehler wie:

```text
Error response from daemon: Conflict. The container name "/assignment-postgres" is already
in use by container "...". You have to remove (or rename) that container to be able to
reuse that name.
```

**Ursache:** Die Container einer vorherigen Uebung laufen noch oder wurden nicht vollstaendig entfernt.

**Loesung:** Wechsle in das Verzeichnis der vorherigen Uebung und raeume dort auf:

```bash
cd assignments/<vorherige-uebung>
docker compose down -v
```

Danach kannst du die aktuelle Uebung normal starten.

## Container starten nicht

```bash
# Status pruefen
docker compose ps

# Logs pruefen
docker compose logs assignment-keycloak
```

## Port bereits belegt

Pruefe, ob die benoetigten Ports frei sind (je nach Modul z.B. `8080`, `5432`, `5173`, `3001`, `3000`, `8025`, `1025`):

```bash
# macOS / Linux
lsof -i :8080

# Windows PowerShell
netstat -ano | findstr :8080
```

## Keycloak nicht erreichbar oder langsam

```bash
docker compose logs -f assignment-keycloak
```

Warte auf eine Meldung wie: `Running the server in development mode.`

## Realm-Import scheint nicht zu greifen

Der Realm-Import wird nur beim **ersten Start** auf ein leeres Datenvolume angewendet.

```bash
docker compose down -v
docker compose up -d
```

> Achtung: `-v` loescht persistente Daten (Volumes).

## Kubernetes / minikube

Gilt fuer `modul-11-kubernetes`. Das Lab nutzt kein `docker compose`; die Befehle oben greifen dort nicht.

### minikube startet nicht

**Symptom:** `minikube start` bricht mit `Docker Desktop has only ... memory` oder
`Exiting due to RSRC_INSUFFICIENT_...` ab.

**Ursache:** Docker Desktop stellt weniger RAM oder CPUs bereit, als `--memory=6144 --cpus=4` anfordert.

**Loesung:** In Docker Desktop unter *Settings -> Resources* mindestens 6 GB RAM und 4 CPUs
freigeben, oder die Compose-Container der vorherigen Uebung mit `docker compose down -v` beenden.

### Keycloak-Pod bleibt Pending

```bash
kubectl -n keycloak describe pod keycloak-0 | tail -20
```

`Insufficient memory` oder `Insufficient cpu` in den Events: Die Requests der Keycloak-CR passen
nicht mehr auf den Knoten. `instances` auf `1` zuruecksetzen oder den Cluster mit mehr Speicher
neu anlegen (`minikube delete`, dann `minikube start` mit hoeherem `--memory`).

### Keycloak-CR wird nicht Ready

```bash
kubectl -n keycloak get keycloak keycloak -o jsonpath='{.status.conditions}'
kubectl -n keycloak logs keycloak-0
```

Haeufige Ursachen:

- `HasErrors` mit Hinweis auf die Datenbank: `postgres-0` laeuft noch nicht oder das Secret
  `postgres-credentials` fehlt. Reihenfolge der Manifeste einhalten.
- `Connection refused` in den Logs beim Start: PostgreSQL ist noch nicht bereit. Keycloak
  versucht es erneut; ein bis zwei Minuten warten.

### Browser landet auf einer internen Adresse oder meldet "Invalid redirect"

**Ursache:** `hostname.hostname` in `manifests/02-keycloak.yaml` stimmt nicht mit der URL im Browser
ueberein, oder `proxy.headers` fehlt und Keycloak erzeugt `http://`-URLs hinter dem TLS-Ingress.

**Loesung:** Beide Felder pruefen, Manifest erneut anwenden. Der Operator rollt die Pods neu aus.

### keycloak.mustertech.test ist nicht erreichbar

- **macOS, Windows:** `minikube tunnel` muss in einem eigenen Terminal laufen und darf nicht
  beendet werden. Es fragt nach dem Administrator-Passwort.
- **Linux:** Die IP aus `minikube ip` muss in der Hosts-Datei stehen, nicht `127.0.0.1`.
- Der Ingress-Controller ist bereit, wenn `kubectl -n ingress-nginx get pods` `Running` zeigt.
- Ein Compose-Lab mit Traefik (Modul 10b) belegt die Ports 80 und 443; erst `docker compose down -v`.

### Realm-Import bleibt haengen

```bash
kubectl -n keycloak get keycloakrealmimport mustertech -o jsonpath='{.status.conditions}'
kubectl -n keycloak get jobs
kubectl -n keycloak logs job/mustertech
```

Der Import laeuft nur, wenn die Keycloak-CR `Ready` ist. Ein Realm, der bereits existiert, wird
nicht erneut importiert; dazu die CR loeschen, den Realm in der Admin-Konsole entfernen und die CR
erneut anwenden.

## Admin Permissions und Client Policies

Gilt fuer `modul-12-pci-dss`.

### Menuepunkt "Permissions" oder "Workflows" fehlt

- **Permissions:** erscheint erst, nachdem unter *Realm settings -> General* der Schalter
  *Admin Permissions* aktiviert und gespeichert wurde. Seite einmal neu laden.
- **Workflows** und der Executor **secret-rotation:** brauchen die Preview-Features aus der
  Compose-Datei (`KC_FEATURES: client-secret-rotation,workflows`). Pruefen mit
  `docker compose logs assignment-keycloak | grep -i preview`.

### Helpdesk sieht keine Benutzer

**Symptom:** `tom.helpdesk` kommt in die Realm-Konsole, die Benutzerliste bleibt leer.

**Ursache:** Die Permission hat nur `reset-password`, aber nicht `view`. Ohne `view` filtert
Keycloak die Liste auf null Treffer.

**Loesung:** Permission oeffnen, Scope `view` ergaenzen, speichern. Danach in der Realm-Konsole
ab- und wieder anmelden.

### Admin nach OTP-Einrichtung ausgesperrt

**Symptom:** Nach dem Binden des Flows `browser-mfa` im Realm `master` ist der OTP-Eintrag in
der App verloren.

**Loesung:** Es gibt keinen Weg zurueck in die Konsole ohne den Code. Lab zuruecksetzen:

```bash
docker compose down -v
docker compose up -d
```

### kcadm.sh fragt nach einem Code

Sobald `admin` ein OTP hat, verlangt `kcadm.sh config credentials` den aktuellen Code. Ihn
eingeben oder den Befehl mit `--totp <code>` aufrufen.
