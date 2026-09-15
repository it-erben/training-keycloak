# LDAP, Active Directory und Keycloak verstehen

Diese 90-Minuten-Einheit vertieft Modul 07. Sie verbindet die Grundlagen von LDAP mit
Anmeldung, Datenhaltung, Gruppenrechten und dem Transfer auf Active Directory.
Die praktische Grundlage ist das vorhandene [OpenLDAP-Lab 07c][lab].

## Ablauf

| Minuten | Inhalt                                       | Durchführung                                  |
| ------- | -------------------------------------------- | --------------------------------------------- |
| 0-15    | Verzeichnisbaum, DN, Suchbasis, Filter, Bind | Folien 1-5; Suchergebnisse vorhersagen lassen |
| 15-30   | Login, lokale Daten und Synchronisierung     | Folien 6-9; Ablauf gemeinsam zeichnen         |
| 30-60   | LDAP anbinden und Gruppen auf Rollen mappen  | Teilnehmer bearbeiten Lab 07c                 |
| 60-75   | Gegenproben zu Suche und Gruppenrechten      | Zusatzaufgabe, in Zweiergruppen               |
| 75-90   | AD, TLS, Kerberos und Lebenszyklus           | Folien 12-17; Transferfragen auswerten        |

Die Folien 10 und 11 leiten die Arbeitsphasen ein. Folie 18 enthält Quellen.
Die Zeitangaben sind Planungswerte. Sind die Grundlagen bereits bekannt, die frei
werdende Zeit für Fehlersuche und die AD-Fragen verwenden.

## Bearbeitbare Unterlagen

- [Folien](slides.md): Einstieg, Login-Diagramm, Datenhaltung, Betrieb und AD-Transfer
- [Teilnehmeraufgabe](aufgabe.md): zwei Gegenproben nach Lab 07c sowie Transferfragen
- [Trainerleitfaden](trainer.md): Erklärtext, erwartete Ergebnisse, Hilfen und Musterantworten
- [Login-Diagramm](images/ldap-login.svg): direkt bearbeitbare SVG-Datei
- [LDIF-Dateien](ldif/): Gruppenänderung und Rücknahme im lokalen Übungsverzeichnis

Für diesen Schwerpunkt die Vertiefungsfolien statt der knappen LDAP-Übersicht in Modul 07
verwenden. Identity Brokering bleibt im ursprünglichen Modul. Die Abläufe beziehen sich
auf Keycloak 26.5 und die Konfiguration von Lab 07c.

## Vorbereitung

Zuerst den Trainerleitfaden lesen. Für die Gruppe das Aufgabenblatt öffnen, die
Musterantworten bleiben beim Trainer. Die Befehle der Zusatzaufgabe gehen vom
Kurs-Repository aus; die ursprüngliche Lab-Anleitung verwendet teilweise `labs/` als Basis.

Das Lab benötigt Docker Compose. Zum Starten und Wechseln gelten die Hinweise in
[Lab 07c][lab]. Vor dem Start einer anderen Übung den eigenen Lab-Zustand bewusst sichern
oder verwerfen: Die Kurs-Labs verwenden dieselben Namen und Ports.

Die Übungen führen keine AD-Verwaltung aus. OpenLDAP dient zum Prüfen der LDAP-Grundlagen;
AD-Schema, Kerberos und produktive TLS-Konfiguration werden erklärt und als Transfer behandelt.

## Folien ausgeben

Mit installiertem Marp CLI aus dem Kurs-Repository:

```bash
marp workshops/ldap-ad/slides.md --pdf --allow-local-files -o /tmp/ldap-ad.pdf
```

Unter PowerShell statt `/tmp/ldap-ad.pdf` einen Pfad in einem vorhandenen
Ausgabeverzeichnis verwenden. Nach Änderungen an Text oder Diagramm die Folien rendern
und ansehen. `pre-commit run --all-files` prüft Markdown, YAML und Links.

[lab]: ../../labs/assignments/modul-07c-ldap-federation/README.md
