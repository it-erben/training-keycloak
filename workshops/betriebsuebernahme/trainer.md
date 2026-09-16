# Trainerunterlage: Betriebsübernahme

## Lernziel und Ablauf

Die Gruppe plant, wie sie eine fremde Keycloak-Installation übernimmt und vor der
Umschaltung prüft. Dabei muss sie entscheiden, welche Daten fehlen, wer sie beschafft
und wann ein Rückfall nötig wird. Das Verfahren hängt vom Softwarestand, den Erweiterungen
und der Frage ab, ob bestehende Sitzungen erhalten bleiben müssen.

| Phase         | Moderation                                                          |
| ------------- | ------------------------------------------------------------------- |
| Einstieg      | Kurzfolien: Übergabeumfang, Methoden und Integrationsvertrag        |
| Gruppenarbeit | Gruppen planen; bei der Planung nach dem öffentlichen Issuer fragen |
| Vorstellung   | Jede Gruppe stellt ihren Entwurf vor                                |
| Auswertung    | Abbruchkriterien und Zustand nach einem Rückfall vergleichen        |

Die Gruppen klären zuerst die Übergabefragen und erarbeiten dann Verfahren und Umschaltplan.
Anschließend legen sie Tests fest und bereiten die Vorstellung vor.
Die Gruppe arbeitet auf Papier. Eine reale Installation wird dabei nicht verändert.

## Was vor der Übernahme geklärt sein muss

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

Die Tabelle zeigt eine mögliche Rollenverteilung. Wenn die Gruppe einen Punkt als geklärt
betrachtet, frage nach, wie sie die Antwort prüfen würde und wer dafür zuständig ist.
"Wir bekommen ein Backup" genügt erst, wenn feststeht, wer es bereitstellt und ob der Restore funktioniert.

Noch vor der Wahl des Verfahrens braucht es eine Entscheidung zu den Sitzungen:
Dürfen sich Benutzer nach der Übernahme neu anmelden müssen? Diese Frage gehört zu den
Anwendungsverantwortlichen und muss vor dem Wartungsfenster beantwortet sein.

## Die vorhandene Exportdatei

Der Admin-Konsolenexport ist ein Partial Export. Reguläre Benutzer fehlen; sensible
Werte wie Client-Secrets werden maskiert. Die Datei reicht deshalb nicht für die
beschriebene Übernahme. Auch ein CLI-Realm-Export ist kein vollständiges Abbild des
Betriebszustands. Sitzungen und Ereignishistorie müssen gesondert betrachtet werden.
Themes, Java-Provider, Infrastruktur und extern verwaltete Secrets sind separat zu sichern.

Wenn jemand den Export als Backup bezeichnet, lass die Gruppe dessen Inhalt aufzählen.
Spätestens bei Partnerkonten, Secrets und Sitzungen wird die Lücke sichtbar.

## Datenbank übernehmen oder Realm exportieren?

| Weg                   | Voraussetzung                                              | Wesentliche Grenze              |
| --------------------- | ---------------------------------------------------------- | ------------------------------- |
| Datenbankübernahme    | Backup-Restore bei gleichem Softwarestand erprobt          | Externe Dateien separat sichern |
| CLI-Export und Import | Vollständiger Export, Quellknoten gestoppt, Import erprobt | Laufende Sitzungen fehlen       |

Für Mustertech bietet sich zuerst die Datenbankübernahme mit identischem Keycloak-Image an,
sofern der Dienstleister den nötigen Zugriff gewährt. Ein Upgrade kann später separat
geplant werden. Persistent gespeicherte Sitzungen können im DB-Backup enthalten sein.
Ob der Browser sie nach dem Umzug weiterverwenden kann, zeigt aber erst ein Test mit der
Zielkonfiguration, den Schlüsseln, Cookies und angeschlossenen Anwendungen.

Akzeptiert Mustertech neue Anmeldungen, kommt auch ein vollständiger CLI-Export mit
anschließendem Import infrage. Dafür müssen sämtliche benötigten Daten und Schlüssel
verfügbar sein. Auch dieser Weg braucht die Mitarbeit des Dienstleisters, denn ohne
Zugriff auf dessen Installation kann das Zielteam den Export nicht erstellen.

Ein Datenbankschema nach einem Versionsupgrade darf nicht ungeprüft mit der alten
Keycloak-Version gestartet werden. Ein Rückfall braucht einen passenden alten Software-
und Datenstand. Der Keycloak Operator ersetzt weder DB-Sicherung noch Migrationsplanung.

## Was für Anwendungen stabil bleiben muss

Die Anwendungen erwarten den bisherigen öffentlichen Issuer aus Keycloak-URL und Realm.
Steht nach dem Umzug ein interner Service-Name statt `login.mustertech.example` darin,
können sie Tokens ablehnen, obwohl Keycloak erreichbar ist. Vergleicht deshalb den Issuer
in Discovery und Token mit der Anwendungskonfiguration. Interne Netzwerkadressen dürfen
davon abweichend konfiguriert sein.

Zu prüfen sind außerdem Client-IDs, Redirect- und Logout-URLs, vertrauliche Client-Secrets,
Schlüsselmaterial, Benutzeridentitäten (`iss`, `sub`) und externe Provider.
Diese Werte müssen auch nach der DNS-Umschaltung zu den Anwendungen passen.

## Beispiel für Abnahme und Umschaltung

Der Beispielplan lässt ab 10:40 Uhr zwanzig Minuten für einen Rückfall. Ob das reicht,
muss eine Probe zeigen. Dauert sie länger, braucht Mustertech ein größeres Wartungsfenster
oder einen früheren Entscheidungspunkt.

| Zeitpunkt   | Handlung und Entscheidung                                                                    |
| ----------- | -------------------------------------------------------------------------------------------- |
| Vorher      | Bestand und Übergabe vollständig; Restore/Import isoliert erprobt                            |
| Vorher      | Alle Anwendungstests bestanden; Rückfallweg und Dauer bestätigt                              |
| 10:00       | Schreibzugriffe am Quellsystem kontrolliert stoppen; zuständige Anwendungen berücksichtigen  |
| Danach      | Letzten konsistenten Datenstand übernehmen; Ziel prüfen                                      |
| Danach      | Öffentlichen Endpunkt umschalten; alte Installation vor parallelen Schreibzugriffen schützen |
| Bis 10:40   | Funktionstests und Fehlerraten prüfen; benannter Verantwortlicher entscheidet                |
| 10:40-11:00 | Erprobten Rückfall ausführen, falls Abnahmekriterien fehlen                                  |

Auch ohne Admin-Konsole entstehen Schreibzugriffe: Benutzer ändern Passwörter, registrieren
sich selbst, Verwaltungs-APIs schreiben Daten und die Föderation synchronisiert Konten.
Die Gruppe muss festlegen, welche dieser Vorgänge sie während der Übernahme zulässt.

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

Bei der API kommen ein falscher Issuer, unpassende Prüfschlüssel, eine falsche Audience
oder veränderte Claims als Ursache infrage. Lass die Gruppe eine davon auswählen und
einen Test beschreiben: etwa den abgelehnten `iss`-Wert mit dem konfigurierten Aussteller
vergleichen. HTTP-Status und Fehlergrund helfen, die Suche einzugrenzen.
Tokens und Secrets gehören nicht in öffentliche Logs oder gemeinsam geteilte Screenshots.

Beim Batch-Dienst Client-ID, Secret-Übergabe, Service-Account-Konfiguration, Rollen und
Erreichbarkeit getrennt prüfen. Ein Portal-Login prüft dessen Client Credentials nicht mit.

In der alten Datenbank steht noch das alte Passwort des Partners. Nach einem Rückfall
würde dessen neues Passwort dort nicht funktionieren. Die Gruppe muss daher entscheiden,
ob sie Änderungen im Ziel zunächst verhindert, vor dem Rückfall übernimmt oder über ein
angekündigtes Wiederherstellungsverfahren behandelt. Dazu gehört auch der Umgang mit
bereits ausgestellten Tokens und Sitzungen. Wegen DNS-Caches können außerdem zeitweise
beide Installationen angesprochen werden.

Frage beim Rückfallplan nach dem Entscheider, der Frist und dem erwarteten Datenstand.
Dann lass die Gruppe formulieren, was sie dem Partner über sein Passwort mitteilt.
An dieser Antwort lässt sich erkennen, ob der Plan die Folgen für Benutzer berücksichtigt.

## Hilfen und Abschluss

Hilfen einzeln geben:

1. "Welche eurer Anwendungen braucht ein Client Secret?"
2. "Welche Daten fehlen im übergebenen Export?"
3. "Was erwartet die API im Feld `iss`?"
4. "Was passiert mit Daten, die nur im neuen System entstanden sind?"

Zum Abschluss jede Gruppe eine fehlende Übergabeinformation nennen lassen, ohne die
sie die Umschaltung ablehnen würde. Eine begründete Absage ist ein gültiges Ergebnis.

## Fachliche Quellen

Die verlinkte Export-Dokumentation beschreibt Keycloak 26.5.0. Die übrigen Betriebsseiten
werden fortlaufend aktualisiert; bei einer realen Übernahme zählt die tatsächlich eingesetzte
Version. Den hier entworfenen Ablauf muss das Betriebsteam an seiner Installation erproben.

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
