# LDAP, Active Directory und Keycloak verstehen

Wie findet Keycloak einen Benutzer im LDAP, wer prüft sein Passwort und wann kommen
geänderte Gruppenrechte bei der Anwendung an? Diese 90-Minuten-Einheit vertieft Modul 07
anhand des [OpenLDAP-Labs 07c][lab]. Anschließend behandelt sie die Unterschiede zu Active Directory.

## Ablauf

| Minuten | Inhalt                                       | Durchführung                                  |
| ------- | -------------------------------------------- | --------------------------------------------- |
| 0-15    | Verzeichnisbaum, DN, Suchbasis, Filter, Bind | Folien 1-5; Suchergebnisse vorhersagen lassen |
| 15-30   | Login, lokale Daten und Synchronisierung     | Folien 6-9; Ablauf gemeinsam zeichnen         |
| 30-60   | LDAP anbinden und Gruppen auf Rollen mappen  | Teilnehmer bearbeiten Lab 07c                 |
| 60-75   | Gegenproben zu Suche und Gruppenrechten      | Zusatzaufgabe, in Zweiergruppen               |
| 75-90   | AD, TLS, Kerberos und Lebenszyklus           | Folien 12-17; Transferfragen auswerten        |

Die Folien 10 und 11 leiten die Arbeitsphasen ein. Folie 18 enthält Quellen.
Kennt die Gruppe LDAP bereits, bleibt mehr Zeit für die Fehlersuche und die AD-Fragen.
Die 15 Minuten für Gegenproben setzen ein fertig eingerichtetes Lab voraus.

## Bearbeitbare Unterlagen

- [Folien](slides.md): vom LDAP-Login bis zu Kontosperren und Windows-SSO
- [Teilnehmeraufgabe](aufgabe.md): zwei Gegenproben nach Lab 07c und Fragen zu AD
- [Trainerleitfaden](trainer.md): Erklärungen zum Vortragen, Musterlösungen und Rückfragen
- [Login-Diagramm](images/ldap-login.svg): direkt bearbeitbare SVG-Datei
- [LDIF-Dateien](ldif/): Gruppenänderung und Rücknahme im lokalen Übungsverzeichnis

Für diesen Schwerpunkt die Vertiefungsfolien statt der knappen LDAP-Übersicht in Modul 07
verwenden. Identity Brokering bleibt im ursprünglichen Modul. Die Abläufe beziehen sich
auf Keycloak 26.5 und die Konfiguration von Lab 07c.

## Vorbereitung

Der Trainerleitfaden folgt dem zeitlichen Ablauf und enthält die Musterantworten.
Während der Übung arbeitet die Gruppe nur mit dem Aufgabenblatt. Dessen Befehle starten
im Hauptverzeichnis des Kurs-Repositories; die ursprüngliche Lab-Anleitung verwendet
teilweise `labs/` als Basis.

Das Lab benötigt Docker Compose. Zum Starten und Wechseln gelten die Hinweise in
[Lab 07c][lab]. Vor dem Start einer anderen Übung den eigenen Lab-Zustand bewusst sichern
oder verwerfen: Die Kurs-Labs verwenden dieselben Namen und Ports.

Die praktischen Versuche laufen in OpenLDAP. AD-Schema, Kerberos und TLS im Produktivbetrieb
werden anhand von Fragen besprochen; ein AD-Server gehört nicht zu dieser Übungsumgebung.

## Folien ausgeben

Mit installiertem Marp CLI aus dem Kurs-Repository:

```bash
marp workshops/ldap-ad/slides.md --pdf --allow-local-files -o /tmp/ldap-ad.pdf
```

Unter PowerShell statt `/tmp/ldap-ad.pdf` einen Pfad in einem vorhandenen
Ausgabeverzeichnis verwenden. Nach Änderungen an Text oder Diagramm die Folien rendern
und ansehen. `pre-commit run --all-files` prüft Markdown, YAML und Links.

[lab]: ../../labs/assignments/modul-07c-ldap-federation/README.md
