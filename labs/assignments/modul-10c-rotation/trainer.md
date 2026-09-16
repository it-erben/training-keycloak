# Musterlösung und Trainerhinweise zu Modul 10c

## Durchführung

10c startet mit einem eigenen Realm. Du kannst es deshalb direkt nach Modul 10 einsetzen
oder nach Modul 12 anschließen, wenn die Teilnehmer ihre bisherige Umgebung bereits abgebaut haben.
Plane 35-45 Minuten ein. Etwa 15 Minuten entfallen auf die Secrets, 20 auf die
Signaturschlüssel; am Schluss bleiben fünf Minuten für die Ergebnistabelle.
Lade die Images und baue die API vor Beginn, damit die Gruppe nicht auf Downloads warten muss.

Alle bearbeiten denselben Ablauf mit vorgegebenen Prüfbefehlen. Erkläre vorab, wo die beiden
Geheimnisse verwendet werden: Das Client-Secret liegt beim Dienst und bei Keycloak. Der private
Signaturschlüssel bleibt bei Keycloak; die API lädt nur den öffentlichen Schlüssel.
Lass die Teilnehmer vor **Invalidate** kurz vorhersagen, ob `before` noch funktioniert.
Nach dem API-Aufruf können sie ihre Vermutung am Ergebnis prüfen.

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

Zum Entwerten dient **Invalidate** neben **Rotated secret**. `before` bleibt bis zu seinem
Ablauf verwendbar: Die API prüft Signatur, Issuer und Zeitangaben des JWT. Ob sich das
Client-Secret seit der Ausstellung geändert hat, fragt sie bei Keycloak nicht ab.

Die `kid` bleibt gleich, weil die Secret-Rotation das Schlüsselpaar des Realms nicht verändert.
Die API-Ausgabe `service-account-sync-service` zeigt außerdem, wer hier zugreift: der Service
Account des Clients. Für diesen Client-Credentials-Flow meldet sich kein Mensch an.

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

Vergleiche die konkreten `kid`-Werte. Obwohl beide Schlüssel 2048 Bit haben und RS256
verwenden, unterscheiden sie sich in ihrer `kid`, über die die API den passenden öffentlichen
Schlüssel findet. Im JWKS können weitere Schlüssel stehen; für diesen Versuch zählen die
Einträge mit RS256 und `use: sig`.

### Cache als Teil des Versuchs

Die wiederverwendete Portal-API verwendet `jwks-rsa` mit aktiviertem Cache. Nach einem
vorherigen erfolgreichen Zugriff kann ein Token noch akzeptiert werden, obwohl Keycloak
den betreffenden öffentlichen Schlüssel nicht mehr veröffentlicht. Vorhandene Cache-Einträge
verschwinden dadurch nicht automatisch.

Nach `docker compose restart api` startet der Prozess mit leerem Cache. Wenn das noch gültige
`key-before` jetzt eine 401-Antwort erhält, fehlt der API der passende öffentliche Schlüssel.
Mit `key-after` klappt der Aufruf weiterhin. Diese Gegenprobe zeigt, dass die API erreichbar
ist und Tokens mit dem neuen Schlüssel prüfen kann.

Zum Abschluss `rsa-original` wieder auf **Enabled: On**, **Active: Off** stellen, die alte
`kid` im JWKS nachweisen, den API-Prozess erneut starten und beide Tokens prüfen.
Damit bleiben ältere Tokens prüfbar und neue Tokens verwenden `rsa-rotation`.

Für die Übergangszeit im Produktivbetrieb zählt, wie lange Anwendungen und Keycloak den alten
Schlüssel noch brauchen. Dabei sind auch ID Tokens und Offline Tokens zu berücksichtigen.
Die eine Stunde aus dem Lab lässt sich deshalb nicht pauschal übernehmen. Kläre außerdem,
wie die beteiligten Anwendungen ihre Schlüssel-Caches erneuern. Der Neustart macht diesen
Effekt hier sichtbar, ersetzt aber keine Planung für die laufenden Anwendungen.

## Typische Verständnisfragen

**Warum funktioniert `before` trotz ungültigem Secret?**
Keycloak hat das Secret bei der Token-Anfrage geprüft und anschließend das Token signiert.
Weil die API dieses JWT anhand der Signatur und Claims prüft, bräuchte sie einen zusätzlichen
Mechanismus, um einen späteren Widerruf zu bemerken.

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

Die Änderungen an Keycloak erfolgen in der Admin-Konsole. Das Prüfwerkzeug fordert Tokens an,
speichert sie und ruft damit `/api/profile` auf. `--expect 401` kennzeichnet einen beabsichtigten
Fehler; bei einem anderen Status endet das Werkzeug mit Exitcode 1.

Vor jeder Token-Anfrage löscht es eine vorhandene Token-Datei mit demselben Namen. Schlägt
der Versuch fehl, kann der nächste API-Aufruf deshalb nicht versehentlich ein älteres Token verwenden.

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
docker compose --profile tools down -v
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

Wenn `/api/health` antwortet, läuft der API-Prozess. Ob Anmeldung und Token-Prüfung funktionieren,
zeigen die Token-Anfragen und die Aufrufe von `/api/profile` aus der Aufgabe.

## Quellen

- [Keycloak: Client Secret Rotation](https://www.keycloak.org/docs/latest/server_admin/index.html#_secret_rotation)
- [Keycloak: Realm-Schlüssel](https://www.keycloak.org/docs/latest/server_admin/index.html#realm_keys)
- [Keycloak 26.5.7: Rotiertes Secret invalidieren](https://github.com/keycloak/keycloak/blob/26.5.7/services/src/main/java/org/keycloak/services/resources/admin/ClientResource.java)
