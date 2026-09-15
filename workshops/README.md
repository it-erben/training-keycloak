# Vertiefende Workshops

Zwei Workshops ergänzen den Kurs um Architekturentscheidungen und die Übernahme einer
bestehenden Keycloak-Installation. Beide verwenden fiktive Fälle der Mustertech GmbH.
Sie benötigen ein gemeinsames Whiteboard oder Papier, aber keine laufende Lab-Umgebung.
Die Beispiele sind für den Kurs mit Keycloak 26.5 eingeordnet.

| Workshop                                             | Voraussetzung                       | Dauer   |
| ---------------------------------------------------- | ----------------------------------- | ------- |
| [Mandantenfähigkeit](mandantenfaehigkeit/aufgabe.md) | Realms, Clients, Federation, Rollen | 60 Min. |
| [Betriebsübernahme](betriebsuebernahme/aufgabe.md)   | Betrieb, Kubernetes und Operator    | 60 Min. |

## Einsatz im Kurs

Mandantenfähigkeit passt nach Modul 07 oder als Vertiefung an Tag 3. Betriebsübernahme
schließt an die Module 10 und 11 an. Modul 12 bleibt ein eigener Schwerpunkt.

Die angegebenen Zeiten sind Planungswerte. Jeder Workshop besteht aus 12 Minuten
fachlichem Einstieg, 23 Minuten Gruppenarbeit, zweimal 7 Minuten Vorstellung und
11 Minuten gemeinsamer Auswertung. Zwei Gruppen mit je drei Personen arbeiten am
selben Fall; die Ergebnisse dürfen sich bei begründeten Annahmen unterscheiden.

In jeder Gruppe zeichnet eine Person, eine hält Entscheidungen fest und eine prüft die
Gegenbeispiele. Die Rollen wechseln im zweiten Workshop.

## Unterlagen

| Zielgruppe   | Mandantenfähigkeit                          | Betriebsübernahme                          |
| ------------ | ------------------------------------------- | ------------------------------------------ |
| Präsentation | [Kurzfolien](mandantenfaehigkeit/slides.md) | [Kurzfolien](betriebsuebernahme/slides.md) |
| Teilnehmende | [Aufgabe](mandantenfaehigkeit/aufgabe.md)   | [Aufgabe](betriebsuebernahme/aufgabe.md)   |
| Trainer      | [Trainer](mandantenfaehigkeit/trainer.md)   | [Trainer](betriebsuebernahme/trainer.md)   |

Die Aufgabenblätter enthalten keine Musterlösung. Die Trainerunterlagen bleiben während
der Gruppenarbeit beim Trainer. Kurzfolien vermitteln die Entscheidungsgrundlagen;
die letzten Folien enthalten den Arbeitsauftrag und die Fragen für die Auswertung.

## Zeitvarianten

- **45 Minuten:** 10 Minuten Einstieg, 15 Minuten Gruppenarbeit, zweimal 5 Minuten
  Vorstellung, 10 Minuten Auswertung. Zusatzfragen entfallen.
- **60 Minuten:** Vollständiger Ablauf wie oben.
- **90 Minuten:** Nach dem Einstieg 35 Minuten Gruppenarbeit einschließlich Zusatzfall,
  zweimal 10 Minuten Vorstellung, 15 Minuten Gegenprüfung und 8 Minuten Abschluss.

## Vorbereitung und Ausgabe

Für die Vorbereitung zuerst die Musterarchitektur in der
[Trainerunterlage zur Mandantenfähigkeit](mandantenfaehigkeit/trainer.md) und die
Übertragungswege in der [Trainerunterlage zur Betriebsübernahme](betriebsuebernahme/trainer.md)
lesen. Danach die Zugriffstests beziehungsweise den Rückfallplan durchgehen und die
Aufgabenblätter sowie zwei Whiteboard-Flächen oder große Papierbögen bereitlegen.

Für die Nachbereitung liegen alle Texte direkt im jeweiligen Workshop-Verzeichnis:

- `slides.md`: fachlicher Einstieg, Arbeitsauftrag und Auswertungsfragen für die Präsentation
- `aufgabe.md`: Fallvorgaben und Arbeitsaufträge für die Teilnehmenden
- `trainer.md`: Musterlösung, vertretbare Alternativen, Moderationshilfen und Quellen

Geänderte Fallvorgaben gemeinsam in Aufgabe, Folien und Musterlösung nachziehen.
Die Markdown-Dateien im Repository sind die Grundlage für weitere Bearbeitungen;
PDFs werden daraus als Ausgabe erzeugt.

Die Markdown-Dateien sind die bearbeitbaren Quellen. Die Kurzfolien verwenden das
Marp-Format des Kurses. PDF-Ausgabe mit installiertem Marp CLI:

```bash
marp workshops/mandantenfaehigkeit/slides.md --pdf -o /tmp/mandantenfaehigkeit.pdf
marp workshops/betriebsuebernahme/slides.md --pdf -o /tmp/betriebsuebernahme.pdf
```

Unter PowerShell kann statt `/tmp/` ein vorhandenes Ausgabeverzeichnis verwendet werden.
Für die Durchführung sind weder Docker-Kommandos noch Änderungen an Clustern erforderlich.

## Quellen

Versionsgebundene Grundlagen und zusätzliche Betriebsquellen stehen in den
Trainerunterlagen. Die Fälle legen ihre Annahmen offen; sie beschreiben keine reale
Kundenarchitektur. Konkrete Migrationsverfahren müssen an einer Kopie der jeweiligen
Installation erprobt werden.
