# Trainerunterlage: Betriebsübernahme

## Lernziel und Ablauf

Die Gruppe soll eine Bestandsaufnahme in einen überprüfbaren Übergabe- und Umschaltplan
übersetzen. Es gibt keinen universellen Migrationsbefehl. Verfahren, Version,
Erweiterungen und Sitzungsanforderungen bestimmen das Vorgehen.

| Minute | Moderation                                                          |
| ------ | ------------------------------------------------------------------- |
| 0-12   | Kurzfolien: Übergabeumfang, Methoden und Integrationsvertrag        |
| 12-35  | Gruppen planen; nach 10 Minuten nach dem öffentlichen Issuer fragen |
| 35-49  | Jede Gruppe stellt sieben Minuten vor                               |
| 49-60  | Abbruchkriterien und Zustand nach einem Rückfall vergleichen        |

Der Fall ist fiktiv. Die Architektur eines realen Kunden darf daraus nicht abgeleitet
werden. Die Gruppe plant auf Papier; ein Cluster oder die Schulungsumgebung wird nicht verändert.

## Acht Fragen an den Dienstleister

| Bereich             | Frage und benötigter Nachweis                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| Softwarestand       | Dienstleister liefert Versionsangabe, Image-Digest und Providerliste.                          |
| Datenübernahme      | Dienstleister und DB-Team belegen Exportumfang oder konsistentes Backup mit Restore-Probe.     |
| Identitäten         | IAM- und AD-Team bestätigen Kontenherkunft, Zuordnung und MFA-Verfahren anhand von Testkonten. |
| Schlüssel/Secrets   | Dienstleister und IAM-Team belegen Schlüsselbestand und Secret-Zugriff per Funktionstest.      |
| Integrationen       | App-Verantwortliche bestätigen Client-Inventar, URLs, Service Accounts und Token-Prüfungen.    |
| Benutzerquellen     | AD- und Plattformteam belegen LDAP-Konfiguration, Zertifikate und Verbindungstests.            |
| Öffentlicher Zugang | Plattformteam belegt Kontrolle über DNS, TLS, Proxy und öffentliche Discovery-Antwort.         |
| Betrieb             | Plattform- und DB-Team übernehmen Konfiguration, Themes, Logs, Backups und Wiederanlaufprobe.  |

Diese Zuordnung ist eine mögliche Rollenverteilung für den Fall. Zu jeder Zeile gehört
die konkrete Frage, ob der genannte Nachweis vollständig vorliegt und wer offene Punkte
bis zur Umschaltung bearbeitet. Stichpunkte genügen in der Gruppenarbeit.

Eine zusätzliche frühe Geschäftsentscheidung ist, ob erneute Anmeldung akzeptabel ist.
Die Zahl und Art der zu erhaltenden Sitzungen darf nicht erst im Wartungsfenster auffallen.

## Die vorhandene Exportdatei

Der Admin-Konsolenexport ist ein Partial Export. Reguläre Benutzer fehlen; sensible
Werte wie Client-Secrets werden maskiert. Die Datei reicht deshalb nicht für die
beschriebene Übernahme. Auch ein CLI-Realm-Export ist kein vollständiges Abbild des
Betriebszustands. Sitzungen und Ereignishistorie müssen gesondert betrachtet werden.
Themes, Java-Provider, Infrastruktur und extern verwaltete Secrets sind separat zu sichern.

Die Aussage "Export ist Backup" muss präzisiert werden: Welche Daten sind enthalten,
welche fehlen und wie wurde die Wiederherstellung geprüft?

## Zwei vertretbare Übertragungswege

| Weg                   | Voraussetzung                                              | Wesentliche Grenze              |
| --------------------- | ---------------------------------------------------------- | ------------------------------- |
| Datenbankübernahme    | Backup-Restore bei gleichem Softwarestand erprobt          | Externe Dateien separat sichern |
| CLI-Export und Import | Vollständiger Export, Quellknoten gestoppt, Import erprobt | Laufende Sitzungen fehlen       |

Für den Fall ist eine Datenbankübernahme mit identischem Keycloak-Image eine plausible
erste Option, sofern der Dienstleister sie ermöglicht. Ein gleichzeitiges Upgrade wird
vermieden. Persistent gespeicherte Sitzungsdaten können zwar in einer DB-Sicherung liegen;
ob Sitzungen nach der Übernahme tatsächlich fortsetzbar sind, muss mit Konfiguration,
Schlüsseln, Cookies und Anwendungen getestet werden.

Alternativ ist ein vollständiger CLI-Export mit anschließendem Import vertretbar, wenn
neue Anmeldungen akzeptiert werden und alle erforderlichen Daten und Schlüssel verfügbar
sind. Ein fehlender DB-Zugang entscheidet nicht automatisch für diesen Weg: Auch der
CLI-Export muss vom Dienstleister ermöglicht werden.

Ein Datenbankschema nach einem Versionsupgrade darf nicht ungeprüft mit der alten
Keycloak-Version gestartet werden. Ein Rückfall braucht einen passenden alten Software-
und Datenstand. Der Keycloak Operator ersetzt weder DB-Sicherung noch Migrationsplanung.

## Was für Anwendungen stabil bleiben muss

Der öffentliche Issuer ergibt sich aus öffentlicher Keycloak-URL und Realm. Ein Wechsel
von `login.mustertech.example` auf einen internen Service-Namen verändert diesen Vertrag,
auch wenn der Server erreichbar ist. Discovery, Token-Aussteller und erwartete Issuer
müssen zusammenpassen. Interne Netzwerkadressen dürfen gesondert konfiguriert sein.

Zu prüfen sind außerdem Client-IDs, Redirect- und Logout-URLs, vertrauliche Client-Secrets,
Schlüsselmaterial, Benutzeridentitäten (`iss`, `sub`) und externe Provider.
Nur DNS umzuschalten belegt weder die Identitätskontinuität noch gültige Integrationen.

## Beispiel für Abnahme und Umschaltung

Die Zeiten unten sind eine mögliche Planung. Eine Probe muss bestätigen, dass Übernahme
und Rückfall tatsächlich ins einstündige Fenster passen. Sonst wird das Fenster erweitert.

| Zeitpunkt   | Handlung und Entscheidung                                                                    |
| ----------- | -------------------------------------------------------------------------------------------- |
| Vorher      | Bestand und Übergabe vollständig; Restore/Import isoliert erprobt                            |
| Vorher      | Alle Anwendungstests bestanden; Rückfallweg und Dauer bestätigt                              |
| 10:00       | Schreibzugriffe am Quellsystem kontrolliert stoppen; zuständige Anwendungen berücksichtigen  |
| Danach      | Letzten konsistenten Datenstand übernehmen; Ziel prüfen                                      |
| Danach      | Öffentlichen Endpunkt umschalten; alte Installation vor parallelen Schreibzugriffen schützen |
| Bis 10:40   | Funktionstests und Fehlerraten prüfen; benannter Verantwortlicher entscheidet                |
| 10:40-11:00 | Erprobten Rückfall ausführen, falls Abnahmekriterien fehlen                                  |

Ein reiner Stopp der Admin-Konsole ist kein vollständiger Schreibstopp. Selbstregistrierung,
Passwortänderungen, API-Verwaltung und föderierte Synchronisation können Daten ändern.
Die erlaubten Schreibvorgänge während der Beobachtung müssen festgelegt sein.

In diesem Beispiel verantwortet die benannte Einsatzleitung des Plattformteams die
Umschaltung und entscheidet spätestens um 10:40 Uhr über den Rückfall. Sie holt dafür
die Abnahme der Anwendungen, des IAM-Teams und des DB-Teams ein. Fehlt eine verpflichtende
Abnahme, wird der erprobte Rückfall ausgelöst. Das DB-Team verantwortet den Datenstand;
die Einsatzleitung informiert Support und betroffene Anwender.

## Muster für fachliche Abnahme

| Prüfung                     | Erwartung / benötigter Nachweis                                  |
| --------------------------- | ---------------------------------------------------------------- |
| AD-Benutzer im Portal       | Login, erwartete Claims und korrekte Identität                   |
| Lokaler Partner mit MFA     | Login samt bestehendem MFA-Verfahren funktioniert                |
| Serverseitige Webanwendung  | Code-Austausch, eigene Sitzung und Logout funktionieren          |
| API mit passendem Token     | Richtige Rolle erlaubt die vorgesehene Aktion                    |
| API mit fehlender Rolle     | Zugriff wird abgewiesen; Grund ist nachvollziehbar               |
| Batch-Dienst                | Client Credentials und benötigte Rechte funktionieren            |
| Sitzungen vor der Übernahme | Vereinbarte Fortsetzung oder angekündigte Neuanmeldung bestätigt |
| Betrieb                     | Health, Logs, Alarmierung und DB-Wiederherstellung geprüft       |

Der Integrationsverantwortliche bestätigt die Anwendungstests. Das Plattformteam
bestätigt Erreichbarkeit und Betrieb; die zuständige Security-Funktion prüft die
vereinbarten Kontrollen. Eine grüne Readiness-Prüfung ersetzt diese Abnahmen nicht.

## Rückfall und Zusatzfall

Die API-Ablehnung kann etwa durch einen falschen Issuer, fehlende beziehungsweise
unpassende Prüfschlüssel, eine falsche Audience oder veränderte Claims entstehen.
Zuerst Status und Fehlergrund aufnehmen, Token-Metadaten und API-Konfiguration vergleichen.
Tokens und Secrets gehören nicht in öffentliche Logs oder gemeinsam geteilte Screenshots.

Beim Batch-Dienst Client-ID, Secret-Übergabe, Service-Account-Konfiguration, Rollen und
Erreichbarkeit getrennt prüfen. Ein Portal-Login prüft dessen Client Credentials nicht mit.

Ein Rückfall auf die alte Datenbank verwirft dort unbekannte Änderungen aus dem Ziel.
Die Passwortänderung des Partners ist deshalb relevant. Vorher klären, ob Zieländerungen
verhindert, kontrolliert übernommen oder mit einem angekündigten Recovery-Verfahren
behandelt werden. Auch bereits ausgegebene Tokens und Sitzungen gehören in diese Entscheidung.
DNS-Caches können zusätzlich dazu führen, dass zeitweise beide Ziele angesprochen werden.

Eine akzeptable Gruppenlösung nennt einen Entscheider, einen Zeitpunkt, technische
Auslöser, den Datenstand nach Rückfall und die Kommunikation an Betroffene.
"DNS zurückstellen und fertig" erfüllt diese Kriterien nicht.

## Hilfen und Abschluss

Hilfen einzeln geben:

1. "Welche eurer Anwendungen braucht ein Client Secret?"
2. "Welche Daten fehlen im übergebenen Export?"
3. "Was erwartet die API im Feld `iss`?"
4. "Was passiert mit Daten, die nur im neuen System entstanden sind?"

Zum Abschluss jede Gruppe eine fehlende Übergabeinformation nennen lassen, ohne die
sie die Umschaltung ablehnen würde. Eine begründete Absage ist ein gültiges Ergebnis.

## Fachliche Quellen

Die versionsgebundene Export-Dokumentation bezieht sich auf Keycloak 26.5.0. Aktuelle
Betriebsdokumentation muss bei einer realen Übernahme gegen die eingesetzte Version
geprüft werden. Dieses Planspiel ist kein erprobter Migrationsleitfaden für eine reale Installation.

- [Import/Export, Keycloak 26.5.0][export-version]
- [Aktuelle Grenzen von Import und Export][export]
- [Vorbereitung eines Upgrades, Keycloak 26.5.0][upgrade]
- [Hostname-Konfiguration][hostname]
- [Keycloak Operator und externe Datenbank][operator]

[export-version]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/guides/server/importExport.adoc
[export]: https://www.keycloak.org/server/importExport
[upgrade]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/upgrading/topics/prep_migration.adoc
[hostname]: https://www.keycloak.org/server/hostname
[operator]: https://www.keycloak.org/operator/basic-deployment
