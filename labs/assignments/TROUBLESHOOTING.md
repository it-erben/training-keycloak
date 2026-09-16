# Zentrales Troubleshooting

Diese Seite gilt fuer alle Module unter `assignments/modul-*`.

## Windows und Bash

### Docker oder Python fehlen in der Shell

Wenn WSL `docker: command not found` meldet, aktiviere in Docker Desktop unter
**Settings -> Resources -> WSL integration** deine Ubuntu-Distribution und klicke auf
**Apply**. Prüfe danach `docker version` in Ubuntu; die Ausgabe muss auch den Server enthalten.

Öffnet `python3` in Git Bash den Microsoft Store, verwende Ubuntu unter WSL für die
Bash-Skripte. Dort müssen `python3 --version` und `curl --version` funktionieren.
Die vollständigen Schritte stehen in der [Windows-Einrichtung](../WINDOWS.md).

### Bash-Skripte melden pipefail oder bash\r

Fehler wie `set: pipefail: invalid option name`, `$'\r': command not found` oder
`/usr/bin/env: 'bash\r': No such file or directory` weisen auf CRLF-Zeilenenden hin.
Die `.gitattributes` des Repositories schreibt LF für `*.sh` vor. Bereits ausgecheckte
Dateien können nach einem Update noch CRLF enthalten.

Wechsle in PowerShell in das Hauptverzeichnis des Repositories und normalisiere die
versionierten Bash-Dateien. Der übrige Inhalt einschließlich eigener Änderungen bleibt erhalten:

```powershell
git ls-files '*.sh' | ForEach-Object {
  $scriptPath = Join-Path (Get-Location) $_
  $content = [IO.File]::ReadAllText($scriptPath).Replace("`r`n", "`n")
  [IO.File]::WriteAllText($scriptPath, $content)
}
git ls-files --eol '*.sh'
```

Die Ausgabe soll für jede Datei `i/lf` und `w/lf` zeigen. Alternativ kannst du im Editor
die Zeilenenden auf LF umstellen. Ein gewöhnliches `git restore` kann eine inhaltlich
unveränderte Datei überspringen und dadurch ihre alten CRLF-Zeilenenden erhalten.

### OpenSSL meldet einen ungültigen Subject-Namen

Git Bash kann `-subj /CN=keycloak.mustertech.test` als Windows-Pfad weiterreichen.
Verwende den PowerShell-Aufruf aus
[Modul 11](modul-11-kubernetes/README.md#schritt-41-selbstsigniertes-zertifikat-erzeugen).
Er startet OpenSSL direkt und vermeidet die MSYS-Pfadkonvertierung.

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

## PostgreSQL 18 startet nicht

**Symptom:** PostgreSQL meldet `/var/lib/postgresql/data (unused mount/volume)`.

Die Compose-Dateien verwenden PostgreSQL 18. Das Datenvolume muss auf
`/var/lib/postgresql` eingebunden sein. Pruefe, ob die aktuelle Compose-Datei verwendet wird.
Der Healthcheck fragt TCP mit `pg_isready -h 127.0.0.1 -U keycloak -d keycloak` ab,
damit der temporaere Server waehrend der Initialisierung nicht als bereit gilt.

Ein altes, entbehrliches Kursvolume kannst du im zugehoerigen Lab mit
`docker compose down -v` entfernen und danach mit `docker compose up -d` neu anlegen.
Dabei gehen die darin gespeicherten Benutzer und Einstellungen verloren.
Ein benoetigter Datenbestand braucht eine Sicherung und eine geplante Migration;
das Aendern des Mountpfads migriert keine bestehende Datenbank.

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

### Audit-Anmeldung nach OTP-Einrichtung

Eine reine Passwort-Anmeldung reicht nach der OTP-Einrichtung des Admins nicht mehr aus.
Verwende das Audit-Skript wie in Modul 12 beschrieben und gib einen frischen Code ein.
`kcadm.sh config credentials` in der verwendeten Version bietet keinen `--totp`-Parameter.

## Rotation in Modul 10c

Die folgenden Befehle werden im Verzeichnis `modul-10c-rotation` ausgeführt.

### Secret-Eingabe zeigt keine Zeichen

Das Prüfwerkzeug blendet die Eingabe aus. Füge das Secret ein und drücke Enter.
Danach bestätigt es den gespeicherten Namen, etwa `old` oder `new`.

### Rotated secret fehlt oder das neue Secret wird abgelehnt

Prüfe, ob das Lab mit dem Realm-Import von 10c gestartet wurde. Unter **Realm settings** ->
**Client policies** muss `lab-confidential` aktiv sein und das Profil `lab-rotation` verwenden.
Erst nach **Regenerate** erscheint das bisherige Secret als **Rotated secret**.

Erhält eine Anfrage mit `new` HTTP 401 und `unauthorized_client`, kopiere das aktuelle
**Client secret** erneut und speichere es:

```bash
docker compose run --rm tools secret new
```

### Token-Datei fehlt oder die API antwortet unerwartet mit HTTP 401

Nur eine erfolgreiche Token-Anfrage speichert ein Token. Führe den zugehörigen Schritt
erneut aus, falls die Datei fehlt. Ist das Token vorhanden, prüfe seine Restlaufzeit:

```bash
docker compose run --rm tools inspect key-before
```

Ein negativer Wert bedeutet, dass das Token abgelaufen ist. Für den Vergleich der Schlüssel
muss `key-before` ausgestellt werden, solange `rsa-original` noch aktiv signiert.
Bei einer 401-Antwort direkt nach dem Deaktivieren des alten Schlüssels kann dessen
Cache-Eintrag bereits abgelaufen sein. Der Cache-Effekt ist damit noch nicht nachgewiesen.
Stelle den alten Provider wieder auf **Enabled: On**, lasse **Active: Off** und prüfe seine
`kid` im JWKS. Wiederhole Schritt 2.4 ab dem API-Neustart und dem Füllen des Caches.
Reicht die Restlaufzeit des Tokens nicht mehr, verwende den vollständigen Reset aus der Aufgabe.

### Neue Tokens haben weiterhin die alte kid

Öffne **Realm settings** -> **Keys** -> **Providers**. Der neue Provider `rsa-rotation`
braucht den Algorithmus `RS256`, Priorität `200` sowie **Enabled: On** und **Active: On**.
Speichere die Einstellungen und fordere ein neues Token an.

### Die API startet nicht

Prüfe die Logs und ob ein anderes Lab die Host-Ports 8080 oder 3001 belegt:

```bash
docker compose logs --tail 40 api keycloak
```
