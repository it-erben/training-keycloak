# JavaScript-Policy: Nur der Besitzer darf löschen

Diese eigenständige Demo führt das Beispiel aus Folienmodul 08 aus. Eine Ressource
`document-1` gehört dem Benutzer `owner`. Der Benutzer `nonowner` besitzt sie nicht.
Die JavaScript-Policy vergleicht die Ressourcenbesitzer-ID mit der Benutzer-ID.

## Voraussetzungen und Start

Du brauchst Docker und Python 3 (nur Standardbibliothek). Der Test verwendet einen eigenen
Keycloak 26.5.7 mit H2, standardmäßig auf `127.0.0.1:18084`. Die Compose-Labs bleiben unverändert.

Starte im Kurs-Repository:

**Bash / macOS / Linux:**

```bash
cd demos/modul-08-zugriffskontrolle-authorization/script-policy
python3 demo.py
```

**PowerShell:**

```powershell
cd demos/modul-08-zugriffskontrolle-authorization/script-policy
py -3 demo.py
```

Ein belegter Port oder bereits vorhandener Containername lässt sich mit
`--port 18085 --name owner-policy-demo-2` umgehen. Bereits vorhandene Container und Images
werden nicht überschrieben.

## Verpackung und Konfiguration

`demo.py` führt diese Schritte aus:

1. `owner-delete.js` und `META-INF/keycloak-scripts.json` in `owner-policies.jar` verpacken.
2. Das JAR mit dem Dockerfile nach `/opt/keycloak/providers/` kopieren und
   `kc.sh build --features=scripts --db=dev-file` ausführen.
3. Den Server mit `start-dev --features=scripts` starten. **Scripts ist ein Preview-Feature**;
   ein Schalter für den früheren Inline-Script-Upload ersetzt dieses Deployment nicht.
4. Realm, beide Benutzer und den Authorization-Client `documents` erstellen.
5. Automatische Standard-Permissions/-Policies entfernen, damit sie keinen Zugriff zusätzlich erlauben.
6. Ressource `document-1` mit Besitzer `owner` und Scope `delete` anlegen. Die deployte Policy
   `Owner delete` über eine Scope-Permission mit dieser Ressource verbinden.
7. Beide Benutzer über Policy-Evaluation und echte UMA-Entscheidungsanfragen prüfen.

Der Deskriptor macht den Policytyp `script-owner-delete.js` für die Authorization Services
verfügbar. Der JavaScript-Code wird aus dem deployten JAR geladen; die Admin-API lädt kein Skript hoch.

## Erwartetes Ergebnis

| Benutzer | Policy-Evaluation | UMA-Entscheidung |
| --- | --- | --- |
| `owner` | `PERMIT` | HTTP 200, `{"result": true}` |
| `nonowner` | `DENY` | HTTP 403, `access_denied` |

Das Programm bricht bei einer abweichenden Entscheidung mit Fehler ab. Anschließend zeigt es
Serverlogs und entfernt seinen Container sowie das selbst gebaute Image. Die temporäre
JAR-/Build-Datei wird ebenfalls entfernt; das Keycloak-Basisimage bleibt im Cache.

Geprüft wird die Entscheidung für `delete`. Eine Dokumenten-Anwendung müsste diese Entscheidung
vor dem tatsächlichen Löschen durchsetzen. H2, lokale Testpasswörter und Passwortgrant dienen
hier allein dem isolierten Beispiel.

Das JAR-Format beschreibt die
[Server-Development-Dokumentation zu 26.5.7](https://github.com/keycloak/keycloak/blob/26.5.7/docs/documentation/server_development/topics/providers.adoc#L412-L499).
