# Trainerlösung: Best Practices & Produktion

## Durchführung

Nach der Anmeldung im Ausgangszustand bearbeitet die Gruppe drei Versuche: HTTPS, Restore und Datenbankausfall.
Jede Person notiert zunächst eine Erwartung. Vor einem neuen Login müssen alle privaten
Browserfenster geschlossen werden, damit keine bestehende SSO-Sitzung den Test verfälscht. Zur
Auswertung genügen der Issuer, die Gegenprobe
nach dem Restore und die Health-Antworten vor, während und nach dem Ausfall.

Die Konfiguration bleibt nach Teil 1 auf HTTPS. Compose lädt `docker-compose.override.yml`
automatisch; zusätzliche `-f`-Argumente oder ein zwischenzeitlicher HTTP-Aufbau sind nicht nötig.
Vor Kursbeginn die Images laden und Docker Compose ab 2.24.4 prüfen. Der CLI-Export ist eine
Zusatzaufgabe, falls nach der Auswertung noch Zeit bleibt.

## HTTPS und öffentlicher Issuer

Die Teilnehmer ergänzen in ihrer Override-Datei:

```yaml
    environment:
      KC_HOSTNAME: https://keycloak.localhost:8443
      KC_HOSTNAME_STRICT: "true"
      KC_HTTP_ENABLED: "true"
      KC_PROXY_HEADERS: xforwarded
```

`KC_HTTP_ENABLED` erlaubt die Verbindung vom Proxy zu Keycloak. `KC_PROXY_HEADERS` lässt
Keycloak unter anderem das ursprüngliche HTTPS-Schema aus `X-Forwarded-Proto` auswerten.
Die vollständige öffentliche URL in `KC_HOSTNAME` bestimmt die nach außen angegebenen Endpunkte.
Traefik muss die Weiterleitungsheader kontrollieren; ein frei erreichbarer interner HTTP-Port
würde die vorgesehene Vertrauensgrenze umgehen.

Erwarteter Discovery-Inhalt:

```json
{
  "issuer": "https://keycloak.localhost:8443/realms/mustertech",
  "authorization_endpoint": "https://keycloak.localhost:8443/realms/mustertech/protocol/openid-connect/auth"
}
```

Das JSON zeigt einen Ausschnitt. Für die Abnahme zusätzlich frisch als Hans anmelden.
`docker compose ps` darf für Keycloak nur die lokale Freigabe von 9000 zeigen; 8443 gehört
zu Traefik. Datenbank und interner HTTP-Port sind nicht auf dem Host veröffentlicht.

Die Zertifikatsausnahme prüft keine vertrauenswürdige Serveridentität. Ein Produktivbetrieb
benötigt ein zum Namen passendes, vertrauenswürdiges Zertifikat. Die sichtbare HTTPS-URL
allein belegt deshalb noch keinen abgenommenen TLS-Aufbau.

**Rückfrage:** "Die Discovery ist korrekt, aber der Login scheitert. Welche Prüfung fehlt uns?"
Mögliche Ansatzpunkte sind Proxy-Header, Redirects, Cookie-Verhalten und die eigentliche
Benutzeranmeldung. Ein erfolgreich abgerufenes JSON testet diesen Ablauf nicht vollständig.

## Wiederherstellung

Der Partial Export enthält die gewählten Konfigurationsobjekte. Reguläre Benutzer wie Hans
fehlen, ebenso ein vollständiger Sicherungsstand der Installation. Service-Account-Einträge
können enthalten sein; daraus darf die Gruppe nicht auf einen vollständigen Benutzerexport schließen.

Beim Datenbankversuch zählt die Reihenfolge:

1. Hans' Anmeldung prüfen und die Datenbank sichern.
2. `restore-probe` anlegen und dessen Vorhandensein bestätigen.
3. Keycloak stoppen, den Dump zurückspielen und Keycloak wieder starten.
4. Realm und Clients prüfen. `restore-probe` muss fehlen, Hans muss sich mit `Muster1234!` neu anmelden können.

Ein erfolgreicher `pg_dump` oder ein lesbares Inhaltsverzeichnis belegt noch keinen funktionierenden
Restore. Die Probe macht die Rückkehr zum früheren Stand sichtbar. Auch andere Datenänderungen
nach dem Backup gehen dabei verloren, beispielsweise Passwortwechsel oder neue Clients.

Außerhalb der Datenbank benötigt diese Installation die passenden Container-Images und
Compose-Dateien sowie die Proxy-Konfiguration. Bei eigenen Themes, Providern, Zertifikaten und
Keystores gehören auch diese Artefakte zum Wiederanlaufplan. Das Lab prüft den Restore mit
passender Version; es demonstriert keine Versionsmigration.

**Rückfrage:** "Wie viel Arbeit verlieren wir bei einem täglichen Backup im ungünstigsten Fall?"
Die Antwort hängt vom Zeitpunkt der letzten Sicherung ab. Aus der verlangten maximalen
Datenlücke folgt eine Backup-Frequenz; aus der maximalen Ausfallzeit folgt, wie schnell Restore
und Abnahme gelingen müssen. Ein pauschaler Wochenplan ersetzt diese Anforderungen nicht.

## Ausfalldiagnose

Der Management-Port verwendet im Lab HTTP und ist nur lokal erreichbar. Der Datenbankcheck
benötigt neben Health auch Metrics; beides ist in der Compose-Datei eingeschaltet.

| Zustand          | Liveness             | Readiness                | Frischer Login        |
| ---------------- | -------------------- | ------------------------ | --------------------- |
| DB verfügbar     | 200, UP              | 200, DB-Check UP         | Erfolgreich           |
| DB gestoppt      | Prozess läuft weiter | Nach Erkennung 503, DOWN | Fehler oder Wartezeit |
| DB wieder bereit | 200, UP              | Nach Erholung 200        | Erneut Erfolg prüfen  |

Liveness kann beim Datenbankausfall weiterhin HTTP 200 liefern. Das ist kein Beleg dafür,
dass Keycloak neue Logins verarbeiten kann. Readiness berücksichtigt die Datenbankverbindung.
Die Erkennung und Erholung hängen vom Connection Pool ab; ein unmittelbar nach dem Stop
noch positives Ergebnis ist Anlass für eine weitere Messung, nicht für einen Neustart.

Eine bereits geladene Seite kann weiter sichtbar sein. Selbst das Abrufen des Login-Formulars
kann durch vorhandene Daten im Cache gelingen. Deshalb verlangt die Aufgabe eine neue Anmeldung.
Die konkrete Browser-Fehlermeldung ist kein Abnahmekriterium; relevant sind der fehlgeschlagene
Vorgang und die zugehörigen Verbindungsfehler im Log.

`docker compose ps -a` zeigt die gestoppte Datenbank. Keycloak kann erst verzögert `unhealthy`
werden, weil sein Container-Healthcheck mehrere Fehlversuche abwartet. Ein Neustart von Keycloak
stellt eine ausgeschaltete Datenbank nicht wieder her. Zuerst PostgreSQL starten, dann Readiness
und Login erneut prüfen. Compose startet einen bloß als `unhealthy` markierten Container nicht
automatisch neu.

Für ein Monitoring braucht es zusätzlich einen Sammler, gespeicherte Zeitreihen und sinnvolle
Alarme. Ein Abruf von `/metrics` belegt lediglich, dass Messwerte bereitstehen. Als Anschlussfrage
bietet sich an: "Welcher Alarm hilft dem Bereitschaftsdienst, und welchen Messwert braucht er zur Diagnose?"

## Zusatzaufgabe: Export vergleichen

Der CLI-Export mit `--realm mustertech` erzeugt `mustertech-realm.json` und bei der voreingestellten
Benutzerstrategie `mustertech-users-0.json`. Im Benutzerexport stehen auch Credential-Daten,
einschließlich Passwort-Hashes. Er gehört wie der Datenbank-Dump nicht ins Repository.
Sitzungen und User-/Admin-Events fehlen im CLI-Export.

Die Unterscheidung in der Auswertung:

| Verfahren       | Beobachtung im Lab                                            |
| --------------- | ------------------------------------------------------------- |
| Partial Export  | Ausgewählte Konfiguration, keine regulären Benutzer           |
| CLI-Export      | Realm und Benutzerkonfiguration, keine Sitzungen/Events       |
| Datenbank-Dump  | Datenbankstand; Wiederherstellung mit Login praktisch geprüft |

## Diagnosehilfen

- **Keycloak startet hinter dem Proxy nicht:** `KC_HTTP_ENABLED` und die Logs prüfen.
- **Discovery nennt HTTP oder einen Containernamen:** `KC_HOSTNAME` in `docker compose config` prüfen.
- **Proxy-Einstellungen fehlen:** Dateiname `docker-compose.override.yml`, Arbeitsverzeichnis und `COMPOSE_FILE` prüfen.
- **Browser findet den Namen nicht:** Hosts-Datei prüfen; `--resolve` gilt nur für den jeweiligen curl-Aufruf.
- **Restore schlägt fehl:** Keycloak muss gestoppt sein. SQL-Fehler vor einem erneuten Start beheben.
- **Kein Datenbankcheck in Readiness:** `KC_HEALTH_ENABLED` und `KC_METRICS_ENABLED` samt verwendetem Image prüfen.

## Quellen

- [Keycloak: Reverse Proxy](https://www.keycloak.org/server/reverseproxy)
- [Keycloak: Import und Export](https://www.keycloak.org/server/importExport)
- [Keycloak: Health Checks](https://www.keycloak.org/observability/health)
