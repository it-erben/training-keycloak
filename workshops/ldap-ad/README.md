# Begleitmaterial zu Modul 07: LDAP und Active Directory

Die LDAP-/AD-Inhalte gehören zum [Foliensatz von Modul 07][folien]. Dieses Verzeichnis
enthält den Trainerleitfaden und die Gegenproben zum [OpenLDAP-Lab 07c][lab].
Für den LDAP-/AD-Block sind 90 Minuten einschließlich Lab vorgesehen; der Einstieg und
die anschließenden Brokering-Themen kommen im Modul hinzu.

## Ablauf

| Minuten | Inhalt                                         | Durchführung                                     |
| ------- | ---------------------------------------------- | ------------------------------------------------ |
| 0-15    | Verzeichnisbaum, DN, Suchbasis, Filter         | Folien 6-8 (2.1-2.3); Suchergebnisse vorhersagen |
| 15-30   | Bind, Login, lokale Daten und Synchronisierung | Folien 9-12 (2.4-2.7); Ablauf gemeinsam erklären |
| 30-60   | LDAP anbinden und Gruppen auf Rollen mappen    | Folie 13 (2.8); Teilnehmer bearbeiten Lab 07c    |
| 60-75   | Gegenproben zu Suche und Gruppenrechten        | Folie 14 (2.9); Zusatzaufgabe in Zweiergruppen   |
| 75-90   | AD, TLS, Kerberos und Lebenszyklus             | Folien 15-20 (2.10-2.15); Fragen auswerten       |

Der LDAP-Block beginnt nach dem Vergleich von Federation und Brokering. Ab Folie 21
geht es im selben Deck mit dem Brokering-Flow, der IdP-Konfiguration, Entra ID,
Social Login und First Broker Login weiter. Folie 28 enthält die Quellen.
Kennt die Gruppe LDAP bereits, bleibt mehr Zeit für die Fehlersuche und die AD-Fragen.
Die 15 Minuten für Gegenproben setzen ein fertig eingerichtetes Lab voraus.

## Bearbeitbare Unterlagen

- [Modul-07-Folien][folien]: vollständiges Modul einschließlich LDAP und AD
- [Teilnehmeraufgabe](aufgabe.md): zwei Gegenproben nach Lab 07c und Fragen zu AD
- [Trainerleitfaden](trainer.md): Erklärungen zum Vortragen, Musterlösungen und Rückfragen
- [Login-Diagramm](../../slides/07-identity-provider-foederation/images/ldap-login.svg): bearbeitbare SVG-Datei
- [LDIF-Dateien](ldif/): Gruppenänderung und Rücknahme im lokalen Übungsverzeichnis

Alle Folien werden direkt im Hauptdeck bearbeitet. Die LDAP-Abläufe beziehen sich auf
Keycloak 26.5 und die Konfiguration von Lab 07c.

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
Wer an Tag 3 gegen ein echtes Active Directory arbeiten will, verwendet die
[AD-Einheit auf GCP](../active-directory/README.md); dort steht auch, wann OpenLDAP der Ersatz bleibt.

## Folien ausgeben

Mit installiertem Marp CLI aus dem Kurs-Repository:

```bash
marp slides/07-identity-provider-foederation/slides.md --pdf --allow-local-files -o /tmp/modul-07.pdf
```

Unter PowerShell statt `/tmp/modul-07.pdf` einen Pfad in einem vorhandenen
Ausgabeverzeichnis verwenden. Nach Änderungen an Text oder Diagramm die Folien rendern
und ansehen. `pre-commit run --all-files` prüft Markdown, YAML und Links.

[lab]: ../../labs/assignments/modul-07c-ldap-federation/README.md
[folien]: ../../slides/07-identity-provider-foederation/slides.md
