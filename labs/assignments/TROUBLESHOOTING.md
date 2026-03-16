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
