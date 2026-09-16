# Musterlösung und Trainerhinweise zu Modul 10c

## Durchführung

Das Lab ergänzt Modul 10 oder folgt als Vertiefung auf Modul 12. Es benötigt keinen Zustand
aus einem anderen Lab. Plane 35-45 Minuten: etwa 15 Minuten für Secrets, 20 Minuten für
Signaturschlüssel und 5 Minuten Auswertung. Bei der Vorbereitung die Images laden und die API bauen.

Die Teilnehmer arbeiten alle denselben Ablauf durch. Zeige zuerst die beiden Vertrauensbeziehungen:
Der Client authentifiziert sich mit seinem Secret an Keycloak. Die API prüft das anschließend
vorgelegte Token mit dem öffentlichen Signaturschlüssel. Stelle vor jeder Änderung eine kurze
Vorhersagefrage und lasse danach den angegebenen Befehl ausführen.

## Vorbereiteter Zustand

- Keycloak 26.5.7 mit dem Preview-Feature `client-secret-rotation`.
- Realm `mustertech`, Client `sync-service`, Service Account und Portal-API aus Modul 06.
- Profil `lab-rotation`: `expiration-period: 86400`, `rotated-expiration-period: 3600`,
  `remaining-rotation-period: 0`; Policy `lab-confidential` für vertrauliche Clients.
- Ausgangsprovider `rsa-original`: RS256, Priorität 100, Enabled und Active eingeschaltet.
- Access Tokens gelten eine Stunde. Bei längeren Unterbrechungen vor der Schlüsselrotation
  ein frisches `key-before` ausstellen, solange `rsa-original` noch aktiv signiert.

Das vorbereitete Secret `rotation-demo-secret` und `admin` / `admin` sind öffentliche Lab-Werte.
Die Datenbank und der Werkzeugspeicher haben projektbezogene Volumes. Die Startdatei verwendet
keine global festgelegten Container-Namen.

## Musterlösung: Secret-Rotation

Die Profile und Policy sind bereits importiert. Auf **Clients** -> **sync-service** ->
**Credentials** reicht deshalb **Regenerate**, um das bisherige Secret als rotiertes Secret
weiterzuführen. Ein weiterer Klick auf **Regenerate** während des Versuchs würde die Zuordnung
von `old` und `new` verändern; rotiere genau einmal.

| Zeitpunkt                          | Altes Secret               | Neues Secret         | Token `before` an der API |
| ---------------------------------- | -------------------------- | -------------------- | ------------------------- |
| Vor Rotation                       | 200                        | Noch nicht vorhanden | 200                       |
| Nach Rotation, Übergangszeit aktiv | 200                        | 200                  | 200                       |
| Nach Invalidate des alten Secrets  | 401, `unauthorized_client` | 200                  | 200                       |

Das alte Secret wird im Feld **Rotated secret** invalidiert, nicht durch erneute Rotation
des aktuellen Secrets. `before` bleibt bis zu seinem Ablauf verwendbar, weil die API weder
Client-Secret noch die aktuelle Credential-Version an Keycloak zurückfragt. Sie prüft
Signatur, Issuer und Zeitangaben des vorgelegten JWT.

Die `kid` bleibt in diesem Teil gleich. Die Secret-Rotation hat das Schlüsselpaar des Realms
nicht verändert. Im Client-Credentials-Flow steht hinter dem Token der Service Account des
Clients, kein angemeldeter menschlicher Benutzer.

## Musterlösung: Signaturschlüssel

Unter **Realm settings** -> **Keys** -> **Providers** einen Provider vom Typ `rsa-generated`
mit Name `rsa-rotation`, Algorithmus RS256, Key size 2048 und Priorität 200 anlegen.
Enabled und Active bleiben eingeschaltet. Der neue Provider erhält eine höhere Priorität
als `rsa-original` und signiert deshalb neue RS256-Tokens.

| Zustand von `rsa-original`           | Alte `kid` im JWKS | Altes Token, leerer Cache | Neues Token an API |
| ------------------------------------ | ------------------ | ------------------------- | ------------------ |
| Enabled On, Active On, Priorität 100 | Ja                 | 200                       | 200                |
| Enabled On, Active Off               | Ja                 | 200                       | 200                |
| Enabled Off, Active Off              | Nein               | 401                       | 200                |
| Wieder Enabled On, Active Off        | Ja                 | 200                       | 200                |

Die zwei `kid`-Werte müssen verschieden sein. Die Schlüsselgröße oder der Algorithmus allein
identifiziert keinen konkreten Schlüssel. Im JWKS können außerdem Schlüssel für andere Zwecke
stehen; für den Versuch zählen RS256 und `use: sig`.

### Cache als Teil des Versuchs

Die wiederverwendete Portal-API verwendet `jwks-rsa` mit aktiviertem Cache. Nach einem
vorherigen erfolgreichen Zugriff kann ein Token noch akzeptiert werden, obwohl Keycloak
den betreffenden öffentlichen Schlüssel nicht mehr veröffentlicht. Vorhandene Cache-Einträge
verschwinden dadurch nicht automatisch.

Nach `docker compose restart api` und erfolgreichem Healthcheck hat der neue Prozess keinen
alten JWKS-Cache. Erst jetzt ist die erwartete 401-Antwort mit `key-before` eindeutig auf
den fehlenden Schlüssel zurückzuführen, sofern das Token noch nicht abgelaufen ist.
Die weiterhin erfolgreiche Anfrage mit `key-after` dient als Gegenprobe.

Zum Abschluss `rsa-original` wieder auf **Enabled: On**, **Active: Off** stellen, die alte
`kid` im JWKS nachweisen, den API-Prozess erneut starten und beide Tokens prüfen.
Damit bleiben ältere Tokens prüfbar und neue Tokens verwenden `rsa-rotation`.

Eine produktive Übergangszeit hängt von allen betroffenen Token-Arten und Verifikatoren ab,
beispielsweise auch von ID Tokens, Offline Tokens und deren Verwendung. Eine Stunde ist
hier nur eine Übungseinstellung. Der demonstrierte API-Neustart ist ein kontrollierter
Cache-Reset; in Produktion braucht jede Anwendung eine passende Aktualisierungsstrategie.

## Typische Verständnisfragen

**Warum funktioniert `before` trotz ungültigem Secret?**
Das Secret wurde zur Ausstellung verwendet. Es steckt nicht als erneut zu prüfendes Passwort
im Access Token. Ohne zusätzlichen Widerrufsmechanismus prüft die API das bereits ausgestellte JWT.

**Warum wird ein passiver Schlüssel noch veröffentlicht?**
Er muss zur Prüfung zuvor signierter Tokens verfügbar bleiben. Active steuert hier das Signieren
neuer Tokens; Enabled steuert die Verfügbarkeit des Providers.

**Ist die Ausgabe von `inspect` schon eine Signaturprüfung?**
Nein. Das Werkzeug dekodiert nur die Base64URL-kodierten Teile. Der API-Aufruf führt die Prüfung
aus. Ein Client-Secret kann die RSA-Signatur eines Tokens weder erzeugen noch verifizieren.

**Ist ein Entfernen aus dem JWKS ein vollständiger Widerruf?**
Nein. Anwendungen können Schlüssel zwischenspeichern; weitere Verifikatoren können eigene
Aktualisierungsregeln verwenden. Deshalb trennt die Aufgabe JWKS-Beobachtung und API-Gegenprobe.

## Prüfwerkzeug und Tests

Das Werkzeug verändert keine Keycloak-Konfiguration. Es sendet Client-Credentials-Anfragen,
speichert die resultierenden Access Tokens und prüft sie an `/api/profile`. Erwartete HTTP-Fehler
werden mit `--expect` angegeben. Ein abweichender Status führt zu Exitcode 1. Vor einer neuen
Token-Anfrage wird eine gleichnamige alte Token-Datei entfernt, damit ein Fehlschlag nicht
versehentlich einen früheren Erfolg vortäuscht.

Unit-Tests, ohne laufendes Keycloak:

```bash
docker compose run --rm --entrypoint python tools -m unittest discover -s /tools
```

Das ist auch unter PowerShell derselbe Befehl. Die Tests prüfen die Eingabenamen, den Umgang
mit einem fehlgeschlagenen Token-Request und unerwartete Statuscodes über einen lokalen HTTP-Testserver.
Die eigentlichen Rotationsschritte müssen zusätzlich gegen das laufende Lab geprüft werden.

## Reset und Diagnose

Ein vollständiger Neustart für einen weiteren Durchlauf:

```bash
docker compose down -v
docker compose up -d --build --wait --wait-timeout 240
docker compose run --rm setup
```

Verwende den Reset nur im Verzeichnis von 10c. Ein Import überschreibt einen vorhandenen Realm
nicht; ein einfacher Container-Neustart setzt deshalb weder Secrets noch Schlüssel zurück.
Bei abweichenden Resultaten zuerst den gespeicherten Token prüfen und dann die Logs lesen:

```bash
docker compose run --rm tools inspect key-before
docker compose logs --tail 50 api keycloak
```

Der lokale Health-Endpunkt der API belegt nur, dass der Prozess antwortet. Die fachliche Abnahme
sind die Token-Anfragen und geschützten API-Aufrufe aus der Aufgabe.

## Quellen

- [Keycloak: Client Secret Rotation](https://www.keycloak.org/docs/latest/server_admin/index.html#_secret_rotation)
- [Keycloak: Realm-Schlüssel](https://www.keycloak.org/docs/latest/server_admin/index.html#realm_keys)
- [Keycloak 26.5.7: Rotiertes Secret invalidieren](https://github.com/keycloak/keycloak/blob/26.5.7/services/src/main/java/org/keycloak/services/resources/admin/ClientResource.java)
