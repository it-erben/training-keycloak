# Modul 10c: Client-Secrets und Signaturschlüssel rotieren

## Übungsziel

Am Ende dieser Übung hast du:

- Ein Client-Secret mit einer Übergangszeit gewechselt und das alte Secret ungültig gemacht
- Bereits ausgestellte Tokens nach der Secret-Rotation an einer API geprüft
- Einen neuen Signaturschlüssel aktiviert und die `kid` alter und neuer Tokens verglichen
- Den Unterschied zwischen einem passiven und einem deaktivierten Schlüssel sowie den JWKS-Cache beobachtet

## Ausgangslage

Der `sync-service` der Mustertech GmbH ruft eine geschützte API auf. Heute wechselst du
sein Client-Secret. Während der Umstellung sollen das alte und das neue Secret kurzzeitig
funktionieren, danach nur noch das neue. Was passiert dabei mit Tokens, die der Dienst
schon besitzt?

Im zweiten Teil wechselst du den Signaturschlüssel des Realms. Auch hier prüfst du an der
API, ob ältere Tokens noch angenommen werden. Dafür verwendest du dieselben gespeicherten
Tokens vor und nach der Änderung.

```text
sync-service -- Token-Anfrage: Client-ID + Secret --> Keycloak
sync-service <-- signiertes Access Token ---------- Keycloak

sync-service -- API-Anfrage mit Access Token ------> Portal-API
Portal-API   -- GET auf den JWKS-Endpunkt ----------> Keycloak
Portal-API   <-- JWKS mit öffentlichen Schlüsseln --- Keycloak
sync-service <-- Antwort nach Token-Prüfung -------- Portal-API
```

Das Secret authentifiziert den Client am Token-Endpunkt. Den privaten Signaturschlüssel
verwendet Keycloak zum Signieren; die API prüft die Signatur mit dem öffentlichen Schlüssel.
Liegt der passende öffentliche Schlüssel bereits im API-Cache, entfällt der JWKS-Abruf.
Im Lab übernimmt das Prüfwerkzeug die Anfragen des `sync-service`.

## Voraussetzungen

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

Der Realm enthält den vertraulichen Client `sync-service` mit Service Account; als API läuft
die Portal-API aus Modul 06. Die Client Policy `lab-confidential` verwendet das Profil
`lab-rotation`. Dadurch gilt ein neues Secret einen Tag, während das bisherige nach der
Rotation noch eine Stunde akzeptiert wird. Auch die Tokens gelten im Lab eine Stunde,
damit sie während der Versuche nicht nebenbei ablaufen.

Diese Laufzeiten sind für die Übung gewählt. Die Verbindungen laufen lokal über HTTP;
im Produktivbetrieb brauchst du TLS und Laufzeiten, die zu deinen Anwendungen passen.

### Das Prüfwerkzeug

Alle Prüfaufrufe beginnen mit `docker compose run --rm tools`. Docker startet dafür einen
Python-Client, der Secrets und Tokens unter den angegebenen Namen im Volume `state` speichert.
So kannst du etwa `before` später erneut prüfen. Auf deinem Rechner brauchst du nur Docker;
Python läuft im Container.

Vollständige Tokens erscheinen nicht in der Ausgabe. Auch die Secret-Eingabe bleibt unsichtbar.
Verwende zum Einfügen gegebenenfalls einen Rechtsklick oder die Einfügefunktion deines Terminals.

Ein HTTP-Status muss zur angegebenen Erwartung passen, sonst endet das Werkzeug mit Fehler.
Die Erwartung ist standardmäßig `200`. Führe jeden Befehl einzeln aus und kläre Abweichungen,
bevor du fortfährst. Die Rotationen nimmst du selbst in der Admin-Konsole vor.

## Teil 1: Client-Secret wechseln

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
Notiere die `kid` des Tokens. An ihr erkennst du, welchen Signaturschlüssel die API zur Prüfung braucht.

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

**Entscheide zuerst:** Im Produktivbetrieb laufen zwei Instanzen des `sync-service`.
Instanz A verwendet bereits das neue Secret, Instanz B noch das alte. Beide können die API
gerade erfolgreich aufrufen, weil sie noch gültige Tokens besitzen.

Darf das alte Secret jetzt invalidiert werden? Notiere deine Entscheidung mit einer Begründung
und benenne die Anfrage, die du vor dem Abschalten auf jeder Instanz erfolgreich prüfen müsstest.
Für diese Frage musst du keine weiteren Container starten.

Im Lab hast du das neue Secret bereits mit einer Token-Anfrage geprüft. Führe hier den Wechsel zu Ende:
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
Die API prüft das vorgelegte Access Token anhand seiner Signatur und Claims.
Dass Keycloak das alte Client-Secret inzwischen ablehnt, erfährt sie dabei nicht.

## Teil 2: Signaturschlüssel wechseln

### Schritt 2.1: Alten Schlüssel zuordnen

Hole unmittelbar vor diesem Versuch ein Token mit dem gültigen neuen Secret:

```bash
docker compose run --rm tools token new key-before
docker compose run --rm tools jwks
```

Notiere die `kid` von `key-before`. Suche sie in der JWKS-Ausgabe; dort gehört sie zu
`alg: RS256` und `use: sig`. Weitere Schlüssel können anderen Algorithmen oder Zwecken dienen.

Öffne **Realm settings** -> **Keys**. Ordne die `kid` dem Provider **rsa-original** zu.
Wechsle zu **Providers** und öffne **rsa-original**. Im Feld **Priority** steht `100`.
Kehre anschließend über **Keys** zur Provider-Liste zurück.

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
Mit **Active: Off** schaltest du das Signieren mit diesem Schlüssel aus. Solange **Enabled: On**
bleibt, können Anwendungen den öffentlichen Schlüssel weiterhin abrufen und ältere Tokens prüfen.

**Vorhersage vor dem nächsten Klick:** Du erhöhst die Priorität von `rsa-original` auf `300`,
lässt den Provider aber passiv. `rsa-rotation` bleibt aktiv mit Priorität `200`.
Welcher Provider wird das nächste Token signieren? Notiere seine erwartete `kid` und begründe
deine Wahl anhand von **Active** und **Priority**.

Stelle nun bei `rsa-original` nur **Priority** auf `300` und speichere. Fordere ein frisches Token an:

```bash
docker compose run --rm tools token new priority-check
```

Vergleiche die ausgegebene `kid` mit deiner Vorhersage. Erkläre eine Abweichung, bevor du
fortfährst. Stelle anschließend **Priority** wieder auf `100`; **Active: Off** und **Enabled: On** bleiben stehen.

### Schritt 2.4: Alten Schlüssel deaktivieren und den Cache prüfen

Jetzt deaktivierst du den alten Schlüssel, obwohl `key-before` noch gültig ist.
Damit untersuchst du, was bei einer zu kurzen Übergangszeit passiert. Im Produktivbetrieb
müsstest du zuvor die Laufzeiten aller betroffenen Token-Arten und die Schlüssel-Caches der
Anwendungen berücksichtigen.

Beginne mit einem frisch gefüllten Cache. Solange `rsa-original` noch **Enabled: On** ist,
starte die API neu und rufe sie mit dem alten Token auf:

```bash
docker compose run --rm tools inspect key-before
docker compose restart api
docker compose up -d --wait --wait-timeout 60 api
docker compose run --rm tools api key-before
```

`key-before` muss noch mindestens fünf Minuten gültig sein; der API-Aufruf muss HTTP 200 liefern.
Der Neustart entfernt ältere Cache-Einträge, der Aufruf lädt den alten Schlüssel neu.
Führe die folgenden Schritte bis zur nächsten API-Anfrage innerhalb einer Minute aus.

Stelle bei **rsa-original** jetzt zusätzlich **Enabled** auf **Off** und speichere.
Prüfe das JWKS:

```bash
docker compose run --rm tools jwks
```

**Erwartet:** Die `kid` von `key-before` fehlt. Prüfe jetzt dasselbe Token an der API:

```bash
docker compose run --rm tools api key-before
```

**Erwartet:** HTTP 200. Obwohl der Schlüssel im JWKS fehlt, kann die API ihn aus ihrem Cache verwenden.
Bei HTTP 401 ist dieser Cache-Effekt noch nicht nachgewiesen. Stelle `rsa-original` wieder auf
**Enabled: On**, prüfe seine `kid` im JWKS und wiederhole diesen Schritt ab dem Füllen des Caches.
Falls die Token-Laufzeit nicht mehr reicht, setze das Lab zurück und beginne erneut.

Leere für eine reproduzierbare Gegenprobe den Prozess-Cache durch einen Neustart ausschließlich der API:

```bash
docker compose restart api
docker compose up -d --wait --wait-timeout 60 api
docker compose run --rm tools api key-before --expect 401
docker compose run --rm tools api key-after
```

**Erwartet:** Das alte Token erhält HTTP 401, das neue weiterhin HTTP 200. Durch den Neustart
musste die API die Schlüssel neu abrufen. Erst der Wechsel von **200 vor dem Neustart zu 401 danach**
zeigt hier den Einfluss des Caches. Das Entfernen aus dem JWKS allein hatte den Zugriff noch nicht verhindert.

### Schritt 2.5: Übergangszustand wiederherstellen

Aktiviere bei **rsa-original** wieder **Enabled: On**, lasse **Active: Off**.
Prüfe zuerst, dass die alte `kid` wieder im JWKS steht. Starte anschließend die API wie in
Schritt 2.4 neu und wiederhole beide Token-Prüfungen mit der Erwartung HTTP 200.
So endest du mit einem neuen aktiven und einem alten passiven Schlüssel.

## Nachsehen und wiederholen

Bei abweichenden Ergebnissen helfen die [Diagnoseschritte für 10c](../TROUBLESHOOTING.md#rotation-in-modul-10c).
Mit `inspect` kannst du die `kid` und Restlaufzeit eines gespeicherten Tokens noch einmal ansehen:

```bash
docker compose run --rm tools inspect key-before
```

`inspect` dekodiert Header und Claims, ohne die Signatur zu prüfen. Dafür rufst du die API auf;
sie prüft auch den Issuer und die Laufzeit. Du brauchst keine öffentliche Decoder-Webseite.

Für einen vollständigen Neustart oder nach Abschluss:

```bash
docker compose --profile tools down -v
```

Mit `--profile tools` wird auch das Volume mit den gespeicherten Secrets und Tokens entfernt.
Der Befehl räumt die Container und Volumes dieses Compose-Projekts auf. Ein erneuter Start stellt den Importzustand her.

## Quellen und Trainerunterlage

- [Keycloak: Signaturschlüssel rotieren](https://www.keycloak.org/docs/latest/server_admin/index.html#rotating-keys)
- [Keycloak: Client-Secret-Rotation](https://www.keycloak.org/docs/latest/server_admin/index.html#_secret_rotation)
- [Musterlösung und Trainerhinweise](trainer.md)
