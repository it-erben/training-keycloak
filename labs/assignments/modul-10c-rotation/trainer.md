# Musterlösung und Trainerhinweise zu Modul 10c

## Durchführung

10c startet mit einem eigenen Realm. Du kannst es deshalb direkt nach Modul 10 einsetzen
oder nach Modul 12 anschließen, wenn die Teilnehmer ihre bisherige Umgebung bereits abgebaut haben.
Lade die Images und baue die API vor Beginn, damit die Gruppe nicht auf Downloads warten muss.

Alle bearbeiten denselben Ablauf mit vorgegebenen Prüfbefehlen. Erkläre vorab, wo die beiden
Geheimnisse verwendet werden: Das Client-Secret liegt beim Dienst und bei Keycloak. Der private
Signaturschlüssel bleibt bei Keycloak; die API lädt nur den öffentlichen Schlüssel.
Lass die Teilnehmer die Frage zu den zwei Dienstinstanzen und die Vorhersage zur Priorität
jeweils vor dem nächsten Schritt beantworten. Sammle die Begründungen, bevor du die Lösung zeigst.

## Vorbereiteter Zustand

- Keycloak 26.5.7 mit dem Preview-Feature `client-secret-rotation`.
- Realm `mustertech`, Client `sync-service`, Service Account und Portal-API aus Modul 06.
- Profil `lab-rotation`: `expiration-period: 86400`, `rotated-expiration-period: 3600`,
  `remaining-rotation-period: 0`; Policy `lab-confidential` für vertrauliche Clients.
- Ausgangsprovider `rsa-original`: RS256, Priorität 100, Enabled und Active eingeschaltet.
- Access Tokens gelten eine Stunde. Bei längeren Unterbrechungen vor der Schlüsselrotation
  ein frisches `TOKEN_KEY_BEFORE` ausstellen, solange `rsa-original` noch aktiv signiert.

Das vorbereitete Secret `rotation-demo-secret` und `admin` / `admin` sind öffentliche Lab-Werte.
Die Datenbank hat ein projektbezogenes Volume. Secrets und Tokens liegen während der Übung
in Shell-Variablen. Die Startdatei verwendet keine global festgelegten Container-Namen.

## Musterlösung: Secret-Rotation

Die Profile und Policy sind bereits importiert. Auf **Clients** -> **sync-service** ->
**Credentials** reicht deshalb **Regenerate**, um das bisherige Secret als rotiertes Secret
weiterzuführen. Ein weiterer Klick auf **Regenerate** während des Versuchs würde die Zuordnung
von `OLD_SECRET` und `NEW_SECRET` verändern; rotiere genau einmal.

| Zeitpunkt                          | Altes Secret               | Neues Secret         | Altes Token an der API |
| ---------------------------------- | -------------------------- | -------------------- | ---------------------- |
| Vor Rotation                       | 200                        | Noch nicht vorhanden | 200                    |
| Nach Rotation, Übergangszeit aktiv | 200                        | 200                  | 200                    |
| Nach Invalidate des alten Secrets  | 401, `unauthorized_client` | 200                  | 200                    |

Zum Entwerten dient **Invalidate** neben **Secret rotated**. `TOKEN_BEFORE` bleibt bis zu seinem
Ablauf verwendbar: Die API prüft Signatur, Issuer und Zeitangaben des JWT. Ob sich das
Client-Secret seit der Ausstellung geändert hat, fragt sie bei Keycloak nicht ab.

Die `kid` bleibt gleich, weil die Secret-Rotation das Schlüsselpaar des Realms nicht verändert.
Die API-Ausgabe `service-account-sync-service` zeigt außerdem, wer hier zugreift: der Service
Account des Clients. Für diesen Client-Credentials-Flow meldet sich kein Mensch an.

### Entscheidung: Zwei Dienstinstanzen umstellen

Das alte Secret darf im beschriebenen Rollout noch nicht entfallen. Instanz B braucht es,
sobald sie ein neues Token anfordert. Ein erfolgreicher API-Aufruf mit einem vorhandenen
Token belegt nur, dass dieses Token noch akzeptiert wird.

Zuerst muss auch B das neue Secret verwenden. Anschließend muss auf jeder Instanz eine
frische Client-Credentials-Anfrage an den Token-Endpunkt mit dem neuen Secret gelingen.
Erst wenn alle verwendenden Instanzen umgestellt und geprüft sind, wird das alte Secret invalidiert.
Die zwei Instanzen sind eine Entscheidungsaufgabe; im Lab stellt das Terminal die Anfragen.

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

### Vorhersage: Ein passiver Schlüssel mit höherer Priorität

Auch mit Priorität `300` signiert `rsa-original` kein neues Token, solange **Active: Off** gilt.
`TOKEN_PRIORITY_CHECK` muss dieselbe `kid` wie `TOKEN_KEY_AFTER` haben und gehört damit zu `rsa-rotation`.
Die Priorität bestimmt die Auswahl unter den geeigneten aktiven Providern. Sie hebt den
passiven Zustand nicht auf.

Danach wird die Priorität von `rsa-original` wieder auf `100` gesetzt. Falls die alte `kid`
erscheint, zuerst die gespeicherten Werte von **Active** und **Priority** prüfen. Entscheidend
für die Auswertung ist, ob die Teilnehmer Auswahl und Signierfähigkeit auseinanderhalten.

### Cache als Teil des Versuchs

Die wiederverwendete Portal-API verwendet `jwks-rsa` mit aktiviertem Cache. Nach einem
vorherigen erfolgreichen Zugriff kann ein Token noch akzeptiert werden, obwohl Keycloak
den betreffenden öffentlichen Schlüssel nicht mehr veröffentlicht. Vorhandene Cache-Einträge
verschwinden dadurch nicht automatisch. Deshalb wird die API vor dem Versuch neu gestartet
und der Cache mit einer erfolgreichen Anfrage für `TOKEN_KEY_BEFORE` gefüllt. Ein weiterer Aufruf
ohne Neustart würde einen bereits vorhandenen Eintrag nicht zuverlässig erneuern.

Nach dem Deaktivieren muss die alte `kid` im JWKS fehlen, während die API das alte Token noch
mit HTTP 200 akzeptiert. Erst dann folgt der zweite API-Neustart. Bei 401 schon vor diesem
Neustart ist kein Cache-Kontrast beobachtet worden; der Versuch wird wie in der Aufgabe beschrieben wiederholt.

Nach `docker compose restart api` startet der Prozess mit leerem Cache. Wenn das noch gültige
`TOKEN_KEY_BEFORE` jetzt eine 401-Antwort erhält, fehlt der API der passende öffentliche Schlüssel.
Mit `TOKEN_KEY_AFTER` klappt der Aufruf weiterhin. Diese Gegenprobe zeigt, dass die API erreichbar
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

**Warum funktioniert `TOKEN_BEFORE` trotz ungültigem Secret?**
Keycloak hat das Secret bei der Token-Anfrage geprüft und anschließend das Token signiert.
Weil die API dieses JWT anhand der Signatur und Claims prüft, bräuchte sie einen zusätzlichen
Mechanismus, um einen späteren Widerruf zu bemerken.

**Warum wird ein passiver Schlüssel noch veröffentlicht?**
Er muss zur Prüfung zuvor signierter Tokens verfügbar bleiben. Active steuert hier das Signieren
neuer Tokens; Enabled steuert die Verfügbarkeit des Providers.

**Ist die Ausgabe von `show_token` oder `Show-Token` schon eine Signaturprüfung?**
Nein. Die Funktion dekodiert nur die Base64URL-kodierten Teile. Der API-Aufruf führt die Prüfung
aus. Ein Client-Secret kann die RSA-Signatur eines Tokens weder erzeugen noch verifizieren.

**Ist ein Entfernen aus dem JWKS ein vollständiger Widerruf?**
Nein. Anwendungen können Schlüssel zwischenspeichern; weitere Verifikatoren können eigene
Aktualisierungsregeln verwenden. Deshalb trennt die Aufgabe JWKS-Beobachtung und API-Gegenprobe.

## HTTP-Anfragen erklären

Bash verwendet `curl` für HTTP und `jq` zum Lesen der JSON-Antwort. PowerShell verwendet
`Invoke-RestMethod` für Token und JWKS sowie `Invoke-WebRequest` für Antworten, deren Status
sichtbar sein soll. Die Anfragen stehen vollständig in der Aufgabe. Der Tools-Container
gehört nicht zum Teilnehmerablauf.

Lass die Gruppe beim ersten Request den Token-Endpunkt, den Grant-Typ und die beiden
Client-Zugangsdaten zeigen. Beim API-Aufruf soll sie den Bearer-Header finden. Frage nach
der Secret-Rotation, warum die API weiterhin dasselbe `TOKEN_BEFORE` erhält.

Die Shell-Variablen bleiben nur im aktuellen Terminal erhalten. Bash ersetzt die Token-Variable
auch bei einer fehlgeschlagenen Anfrage; `pipefail`, `--fail-with-body` und `jq -e` zeigen den
Fehler an. PowerShell leert sie vor der Anfrage und bricht bei einem HTTP-Fehler ab.
Die erwarteten 401-Antworten werden separat ausgegeben und nicht als Token gespeichert.
Bei API-Aufrufen vergleichen die Teilnehmer den sichtbaren Status selbst mit der Erwartung.

## Optionales Prüfwerkzeug

`tools/lab.py` bleibt für automatisierte Prüfungen und Trainerdiagnosen erhalten. Es ist ein
separater HTTP-Client, kein Bestandteil von Keycloak. Seine benannten Dateien haben keinen
Zugriff auf die Shell-Variablen der Teilnehmer. Für die Aufgabe muss der Container weder
gestartet noch verstanden werden.

Unit-Tests, ohne laufendes Keycloak:

```bash
docker compose run --rm --entrypoint python tools -m unittest discover -s /tools
```

Die Tests prüfen die Eingabenamen, den Umgang mit einem fehlgeschlagenen Token-Request und
unerwartete Statuscodes über einen lokalen HTTP-Testserver. Sie prüfen nicht die Befehle
in der Anleitung. Diese müssen zusätzlich mit Bash und PowerShell gegen das Lab laufen.

## Reset und Diagnose

Ein vollständiger Neustart für einen weiteren Durchlauf:

```bash
docker compose --profile tools down -v
docker compose up -d --build --wait --wait-timeout 240
docker compose run --rm setup
```

Mit `--profile tools` wird beim Reset auch ein eventuell vorhandener Werkzeugspeicher entfernt.
Öffne für den nächsten Durchlauf ein neues Terminal und beginne mit dessen Vorbereitung aus
der Aufgabe. Verwende den Reset nur im Verzeichnis von 10c. Ein Import überschreibt einen vorhandenen Realm
nicht; ein einfacher Container-Neustart setzt deshalb weder Secrets noch Schlüssel zurück.
Bei abweichenden Resultaten zuerst `TOKEN_KEY_BEFORE` mit der Dekodierfunktion aus der
Aufgabe prüfen und dann die Logs lesen:

```bash
docker compose logs --tail 50 api keycloak
```

Wenn `/api/health` antwortet, läuft der API-Prozess. Ob Anmeldung und Token-Prüfung funktionieren,
zeigen die Token-Anfragen und die Aufrufe von `/api/profile` aus der Aufgabe.

## Quellen

- [Keycloak: Client Secret Rotation](https://www.keycloak.org/docs/latest/server_admin/index.html#_secret_rotation)
- [Keycloak: Realm-Schlüssel](https://www.keycloak.org/docs/latest/server_admin/index.html#realm_keys)
- [Keycloak 26.5.7: Rotiertes Secret invalidieren](https://github.com/keycloak/keycloak/blob/26.5.7/services/src/main/java/org/keycloak/services/resources/admin/ClientResource.java)
