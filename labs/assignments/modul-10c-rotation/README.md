# Modul 10c: Client-Secrets und Signaturschlüssel rotieren

## Übungsziel

Am Ende dieser Übung hast du:

- Ein Client-Secret mit einer Übergangszeit gewechselt und das alte Secret ungültig gemacht
- Bereits ausgestellte Tokens nach der Secret-Rotation an einer API geprüft
- Einen neuen Signaturschlüssel aktiviert und die `kid` alter und neuer Tokens verglichen
- Den Unterschied zwischen einem passiven und einem deaktivierten Schlüssel sowie den JWKS-Cache beobachtet

**Geschätzte Dauer:** 35-45 Minuten, ohne erstmalige Image-Downloads.

## Ausgangslage

Der `sync-service` der Mustertech GmbH ruft eine geschützte API auf. Seine Zugangsdaten
sollen gewechselt werden. Anschließend wechselt der Betreiber den Schlüssel, mit dem
Keycloak Tokens signiert. Du führst beide Vorgänge getrennt durch und prüfst nach jedem
Schritt, welche Anfragen noch funktionieren.

```text
sync-service -- Client-ID + Secret --> Keycloak -- signiertes Access Token --> sync-service
sync-service -- Access Token --> Portal-API -- öffentliche Schlüssel aus JWKS --> Keycloak
```

Das Secret authentifiziert den Client am Token-Endpunkt. Den privaten Signaturschlüssel
verwendet Keycloak zum Signieren; die API prüft die Signatur mit dem öffentlichen Schlüssel.
Die zwei Rotationen ändern deshalb unterschiedliche Dinge.

## Voraussetzungen und Start

- Docker Desktop und Docker Compose mit `--wait`-Unterstützung
- Grundkenntnisse zu Clients, Access Tokens und Token-Prüfung aus Modul 06
- Bash oder PowerShell; alle Befehle unten funktionieren in beiden Shells

Das Lab ist eigenständig und kann auch nach Modul 12 durchgeführt werden. Es verwendet
Keycloak 26.5.7 und für die Secret-Übergangszeit das Preview-Feature `client-secret-rotation`.

> **Hinweis:** Stoppe vor dem Start die Container der vorherigen Übung mit
> `docker compose down -v` in deren Verzeichnis, wenn sie die Ports 8080 oder 3001 belegen.
> Dabei werden deren Lab-Daten gelöscht. Siehe [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).
> 10c hat eigene Volumes im Compose-Projekt `keycloak-10c`.

Wechsle vom Verzeichnis `labs/` in das Lab und starte die Dienste:

```bash
cd assignments/modul-10c-rotation
docker compose up -d --build --wait --wait-timeout 240
docker compose run --rm setup
```

Warte auf den erfolgreichen Abschluss beider Befehle. Öffne <http://localhost:8080/admin/>
und melde dich mit `admin` / `admin` an. Wähle den Realm **mustertech**.

Vorbereitet sind der vertrauliche Client `sync-service`, dessen Service Account und die
Portal-API aus Modul 06. Die Client Policy `lab-confidential` bindet das Profil `lab-rotation`:
Ein neues Secret gilt einen Tag, das rotierte Secret eine weitere Stunde. Die Tokens gelten
in diesem Lab ebenfalls eine Stunde, damit sie während der Versuche nicht nebenbei ablaufen.
Das sind Übungswerte, keine Empfehlung für den Produktivbetrieb. Die lokalen HTTP-Verbindungen
vereinfachen das Lab; außerhalb dieser Testumgebung gehört TLS dazu.

### Das Prüfwerkzeug

`docker compose run --rm tools ...` startet einen kleinen Python-Client im Container.
Auf dem Host musst du weder Python installieren noch Token-Variablen zwischen Shells übertragen.
Das Werkzeug speichert Secrets und Tokens im eigenen Docker-Volume `state` und gibt keine
vollständigen Tokens aus. Die Secrets gibst du verdeckt ein; zum Einfügen kann ein Rechtsklick
oder die Einfügefunktion deines Terminals nötig sein.

Ein HTTP-Status muss zur angegebenen Erwartung passen, sonst endet das Werkzeug mit Fehler.
Die Erwartung ist standardmäßig `200`. Führe jeden Befehl einzeln aus und kläre Abweichungen,
bevor du fortfährst. Die Rotationen nimmst du selbst in der Admin-Konsole vor.

## Teil 1: Client-Secret wechseln (15-20 Minuten)

### Schritt 1.1: Ausgangszustand prüfen

Öffne **Clients** -> **sync-service** -> **Credentials**. Kopiere das aktuelle **Client secret**.
Speichere es im Werkzeug unter dem Namen `old`:

```bash
docker compose run --rm tools secret old
```

Füge das Secret bei der Eingabeaufforderung ein. Fordere damit ein Token an, speichere es
als `before` und rufe die API auf:

```bash
docker compose run --rm tools token old before
docker compose run --rm tools api before
```

**Erwartet:** zweimal HTTP 200. Die API meldet `service-account-sync-service`.
Notiere die `kid` des Tokens. Sie bezeichnet den Signaturschlüssel, nicht das Client-Secret.

### Schritt 1.2: Secret mit Übergangszeit rotieren

Klicke bei **Client secret** auf **Regenerate** und bestätige gegebenenfalls den Dialog.
Die Credentials-Seite zeigt nun das aktuelle und das rotierte Secret samt Ablaufzeit.
Kopiere das **neue aktuelle** Secret und speichere es als `new`:

```bash
docker compose run --rm tools secret new
docker compose run --rm tools token old overlap-old
docker compose run --rm tools token new overlap-new
```

**Erwartet:** Beide Token-Anfragen liefern HTTP 200. Die vorbereitete Policy ermöglicht diese
Übergangszeit. Vergleiche die `kid` beider Tokens mit `before`: Sie hat sich nicht geändert.

### Schritt 1.3: Altes Secret ungültig machen

Auf derselben Credentials-Seite klicke beim **Rotated secret** auf **Invalidate** und bestätige.
Teste danach dieselben Anmeldeinformationen erneut:

```bash
docker compose run --rm tools token old rejected --expect 401
docker compose run --rm tools token new after-secret
```

**Erwartet:** Das alte Secret erhält HTTP 401 mit `unauthorized_client`. Das neue erhält HTTP 200.
Die fehlgeschlagene Anfrage legt keine Token-Datei `rejected` an.

Prüfe nun das **vor der Rotation ausgestellte** Token an der API:

```bash
docker compose run --rm tools api before
```

**Erwartet:** HTTP 200, solange das Token noch nicht abgelaufen ist.
Die API bekommt das Access Token, nicht das Client-Secret. Das Ungültigmachen des Secrets
widerruft dieses bereits ausgestellte Token nicht.

## Teil 2: Signaturschlüssel wechseln (15-20 Minuten)

### Schritt 2.1: Alten Schlüssel zuordnen

Hole unmittelbar vor diesem Versuch ein Token mit dem gültigen neuen Secret:

```bash
docker compose run --rm tools token new key-before
docker compose run --rm tools jwks
```

Notiere die `kid` von `key-before`. Suche sie in der JWKS-Ausgabe; dort gehört sie zu
`alg: RS256` und `use: sig`. Weitere Schlüssel können anderen Algorithmen oder Zwecken dienen.

Öffne **Realm settings** -> **Keys**. Ordne die `kid` dem Provider **rsa-original** zu.
Unter **Providers** hat dieser Provider die Priorität `100`.

### Schritt 2.2: Einen neuen Schlüssel aktivieren

Unter **Keys** -> **Providers** wähle **Add provider** -> **rsa-generated**.
Konfiguriere:

| Einstellung | Wert           |
| ----------- | -------------- |
| Name        | `rsa-rotation` |
| Priority    | `200`          |
| Enabled     | On             |
| Active      | On             |
| Algorithm   | `RS256`        |
| Key size    | `2048`         |

Speichere und fordere ein neues Token an:

```bash
docker compose run --rm tools token new key-after
docker compose run --rm tools jwks
docker compose run --rm tools api key-before
docker compose run --rm tools api key-after
```

**Erwartet:** Das neue Token hat eine andere `kid`. Beide öffentlichen Signaturschlüssel
stehen im JWKS und beide Tokens werden von der API mit HTTP 200 akzeptiert.
Das neue Schlüsselpaar wird wegen seiner höheren Priorität für neue RS256-Tokens verwendet.

### Schritt 2.3: Alten Schlüssel passiv machen

Öffne den Provider **rsa-original**. Stelle **Active** auf **Off**, lasse **Enabled** auf **On**
und speichere. Teste das alte Token erneut:

```bash
docker compose run --rm tools jwks
docker compose run --rm tools api key-before
```

**Erwartet:** Der alte öffentliche Schlüssel bleibt veröffentlicht; das alte Token funktioniert.
Passiv bedeutet hier: Der Schlüssel dient noch zur Prüfung vorhandener Tokens, aber nicht mehr
zum Signieren neuer Tokens. Das neue Schlüsselpaar bleibt aktiv.

### Schritt 2.4: Alten Schlüssel deaktivieren und den Cache prüfen

Dieser Schritt zeigt absichtlich eine zu frühe Entfernung. Im normalen Betrieb muss die
Übergangszeit alle betroffenen Token-Arten, deren Laufzeiten und die Cache-Strategie berücksichtigen.

Stelle bei **rsa-original** jetzt zusätzlich **Enabled** auf **Off** und speichere.
Prüfe das JWKS:

```bash
docker compose run --rm tools jwks
```

**Erwartet:** Die `kid` von `key-before` fehlt. Die API hat den alten Schlüssel allerdings bereits
abgerufen und zwischengespeichert. Prüfe, ob dieser Cache-Eintrag noch wirksam ist:

```bash
docker compose run --rm tools api key-before
```

Solange der alte Schlüssel im Cache liegt, kann die API weiterhin HTTP 200 liefern. Bei bereits
abgelaufenem Cache erhältst du HTTP 401 und das Werkzeug meldet eine Abweichung. Beides notierst du.
**Das Entfernen aus dem JWKS ist keine sofortige globale Tokensperre.**

Leere für eine reproduzierbare Gegenprobe den Prozess-Cache durch einen Neustart ausschließlich der API:

```bash
docker compose restart api
docker compose up -d --wait --wait-timeout 60 api
docker compose run --rm tools api key-before --expect 401
docker compose run --rm tools api key-after
```

**Erwartet:** Das alte Token erhält HTTP 401, das neue weiterhin HTTP 200. Der Neustart dient hier
der Messung mit leerem Cache; er ist keine allgemeine Anleitung zur Schlüsselrotation in Produktion.

### Schritt 2.5: Übergangszustand wiederherstellen

Aktiviere bei **rsa-original** wieder **Enabled: On**, lasse **Active: Off**.
Prüfe zuerst, dass die alte `kid` wieder im JWKS steht. Starte anschließend die API wie in
Schritt 2.4 neu und wiederhole beide Token-Prüfungen mit der Erwartung HTTP 200.
So endest du mit einem neuen aktiven und einem alten passiven Schlüssel.

## Ergebnis festhalten (5 Minuten)

Trage die tatsächlich beobachteten HTTP-Statuscodes ein:

| Prüfung                                                | Ergebnis |
| ------------------------------------------------------ | -------- |
| Neues Token mit altem Secret während der Übergangszeit |          |
| Neues Token mit altem Secret nach Invalidierung        |          |
| Bereits ausgestelltes Token nach Secret-Invalidierung  |          |
| Altes Token bei passivem Signaturschlüssel             |          |
| Altes Token bei deaktiviertem Schlüssel, leerer Cache  |          |
| Neues Token mit neuem Signaturschlüssel                |          |

Erkläre anhand dieser Tabelle, welche Rotation den Zugang zum Token-Endpunkt verändert
und welche Rotation die Prüfung bereits ausgestellter Tokens betrifft.

## Hilfe und Wiederholung

- **Secret-Eingabe bleibt leer sichtbar:** Das Werkzeug unterdrückt die Anzeige absichtlich. Einfügen, dann Enter.
- **Kein Rotated secret sichtbar:** Prüfe, ob du im frischen Lab 10c bist und `lab-confidential` aktiv ist.
- **`unauthorized_client` mit `new`:** Kopiere das aktuelle Secret erneut; nicht das Feld Rotated secret.
- **Token-Datei fehlt:** Führe die zugehörige erfolgreiche Token-Anfrage aus. Ein Fehler speichert kein Token.
- **Unerwartetes HTTP 401:** Prüfe die Restlaufzeit mit dem untenstehenden Befehl. Negative Werte bedeuten abgelaufen.
- **Neue Tokens haben die alte `kid`:** Algorithmus RS256, Priorität 200 und Active/Enabled des neuen Providers prüfen.
- **API startet nicht:** Prüfe `docker compose logs --tail 40 api keycloak` und freie Host-Ports.

```bash
docker compose run --rm tools inspect key-before
```

`inspect` dekodiert nur Header und Claims. Erst der API-Aufruf prüft die Signatur, den Issuer
und die Laufzeit. Tokens aus diesem Lab gehören nicht in öffentliche Decoder-Webseiten.

Für einen vollständigen Neustart oder nach Abschluss:

```bash
docker compose down -v
```

Damit werden ausschließlich die Container und Volumes dieses Compose-Projekts entfernt,
einschließlich gespeicherter Secrets und Tokens. Ein erneuter Start stellt den Importzustand her.

## Quellen und Trainerunterlage

- [Keycloak: Signaturschlüssel rotieren](https://www.keycloak.org/docs/latest/server_admin/index.html#rotating-keys)
- [Keycloak: Client-Secret-Rotation](https://www.keycloak.org/docs/latest/server_admin/index.html#_secret_rotation)
- [Musterlösung und Trainerhinweise](trainer.md)
