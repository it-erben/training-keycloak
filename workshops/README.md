# Vertiefende Workshops

Drei Workshops ergänzen den Kurs mit Keycloak 26.5. Die LDAP-Einheit führt ins vorhandene
OpenLDAP-Lab. In den beiden Planspielen entwirft die Gruppe eine Architektur für die
fiktive Mustertech GmbH und plant anschließend die Übernahme einer Keycloak-Installation.
Für die Planspiele genügen Whiteboard oder Papier.

| Workshop                                             | Voraussetzung                       | Dauer   |
| ---------------------------------------------------- | ----------------------------------- | ------- |
| [LDAP und Active Directory](ldap-ad/README.md)       | Modul 07, Docker Compose            | 90 Min. |
| [Mandantenfähigkeit](mandantenfaehigkeit/aufgabe.md) | Realms, Clients, Federation, Rollen | 60 Min. |
| [Betriebsübernahme](betriebsuebernahme/aufgabe.md)   | Betrieb, Kubernetes und Operator    | 60 Min. |

## Einsatz im Kurs

Die LDAP-Einheit gehört zu Modul 07. Sie erklärt den Weg vom Verzeichniseintrag bis zur
Berechtigung in der Anwendung. Zwei Gegenproben machen Suchfehler und verzögert sichtbare
Gruppenänderungen im Lab nachvollziehbar.

Mandantenfähigkeit passt nach Modul 07 oder als Vertiefung an Tag 3. Betriebsübernahme
schließt an die Module 10 und 11 an. Modul 12 bleibt ein eigener Schwerpunkt.

Für jedes Planspiel sind 12 Minuten Einstieg, 23 Minuten Gruppenarbeit, zweimal 7 Minuten
Vorstellung und 11 Minuten Auswertung vorgesehen. Zwei Dreiergruppen bearbeiten denselben
Fall. Dabei dürfen unterschiedliche Entwürfe entstehen, solange die Gruppen erklären,
welche Anforderungen ihre Entscheidung bestimmen.

In jeder Gruppe zeichnet eine Person, eine hält Entscheidungen fest und eine prüft die
Gegenbeispiele. Die Rollen wechseln im zweiten Workshop.

## Unterlagen

| Zielgruppe   | Mandantenfähigkeit                          | Betriebsübernahme                          |
| ------------ | ------------------------------------------- | ------------------------------------------ |
| Präsentation | [Kurzfolien](mandantenfaehigkeit/slides.md) | [Kurzfolien](betriebsuebernahme/slides.md) |
| Teilnehmende | [Aufgabe](mandantenfaehigkeit/aufgabe.md)   | [Aufgabe](betriebsuebernahme/aufgabe.md)   |
| Trainer      | [Trainer](mandantenfaehigkeit/trainer.md)   | [Trainer](betriebsuebernahme/trainer.md)   |

Die Gruppe erhält das Aufgabenblatt. Die Musterlösung bleibt beim Trainer, bis beide
Entwürfe vorgestellt sind. Die Kurzfolien liefern den fachlichen Einstieg, den
Arbeitsauftrag und die Fragen für die anschließende Diskussion.

## Zeitvarianten

- **45 Minuten:** 10 Minuten Einstieg, 15 Minuten Gruppenarbeit, zweimal 5 Minuten
  Vorstellung, 10 Minuten Auswertung. Zusatzfragen entfallen.
- **60 Minuten:** Vollständiger Ablauf wie oben.
- **90 Minuten:** Nach dem Einstieg 35 Minuten Gruppenarbeit einschließlich Zusatzfall,
  zweimal 10 Minuten Vorstellung, 15 Minuten Gegenprüfung und 8 Minuten Abschluss.

In der 90-Minuten-Variante bearbeiten die Gruppen zunächst 23 Minuten den Hauptfall.
Dann erhalten sie den Zusatzfall und haben weitere 12 Minuten, um ihren Entwurf anzupassen.
Bei der Vorstellung zeigen sie beide Fassungen und erklären, was sich geändert hat.

## Vorbereitung und Ausgabe

Zur Vorbereitung dienen die Musterarchitektur in der
[Trainerunterlage zur Mandantenfähigkeit](mandantenfaehigkeit/trainer.md) und die beiden
Übertragungsverfahren in der [Trainerunterlage zur Betriebsübernahme](betriebsuebernahme/trainer.md).
Die Zugriffstests und der Rückfallplan enthalten die Fragen, an denen sich die Entwürfe
später prüfen lassen. Für jede Gruppe werden ein Aufgabenblatt und eine Whiteboard-Fläche
oder ein großer Papierbogen benötigt.

Für die Nachbereitung liegen alle Texte direkt im jeweiligen Workshop-Verzeichnis:

- `slides.md`: fachlicher Einstieg, Arbeitsauftrag und Auswertungsfragen für die Präsentation
- `aufgabe.md`: Ausgangslage und Aufgaben für die Teilnehmenden
- `trainer.md`: Musterlösung, alternative Entwürfe, Rückfragen und Quellen

Alle Texte lassen sich direkt in den Markdown-Dateien bearbeiten. Ändert sich eine
Anforderung des Falls, müssen Aufgabe, Folien und Musterlösung weiterhin zusammenpassen.
Die Folien verwenden Marp; PDFs entstehen mit installiertem Marp CLI:

```bash
marp workshops/mandantenfaehigkeit/slides.md --pdf -o /tmp/mandantenfaehigkeit.pdf
marp workshops/betriebsuebernahme/slides.md --pdf -o /tmp/betriebsuebernahme.pdf
```

Unter PowerShell kann statt `/tmp/` ein vorhandenes Ausgabeverzeichnis verwendet werden.
Die LDAP-Einheit hat eine eigene [Vorbereitung und Anleitung zur PDF-Ausgabe](ldap-ad/README.md).

## Quellen

Die Trainerunterlagen verlinken die verwendete Keycloak-Dokumentation. Die Planspiele
arbeiten mit erfundenen Ausgangslagen. Wer einen Entwurf auf eine reale Installation
überträgt, muss deren Anforderungen prüfen und die Migration an einer Kopie erproben.
