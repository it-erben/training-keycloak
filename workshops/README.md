# Workshops und Begleitmaterial

Zwei Planspiele ergänzen den Kurs mit Keycloak 26.5: Die Gruppe entwirft eine Architektur
für die fiktive Mustertech GmbH und plant die Übernahme einer Keycloak-Installation.
Dafür genügen Whiteboard oder Papier. Außerdem liegt hier das Begleitmaterial zum
LDAP-/AD-Block in Modul 07 mit Trainerleitfaden und Gegenproben für das OpenLDAP-Lab.

| Einheit                                                | Voraussetzung                       |
| ------------------------------------------------------ | ----------------------------------- |
| [LDAP und Active Directory](ldap-ad/README.md)         | Modul 07, Docker Compose            |
| [Active Directory auf GCP](active-directory/README.md) | Modul 06b, Modul 07 mit Lab 07c     |
| [Mandantenfähigkeit](mandantenfaehigkeit/aufgabe.md)   | Realms, Clients, Federation, Rollen |
| [Betriebsübernahme](betriebsuebernahme/aufgabe.md)     | Betrieb, Kubernetes und Operator    |

## Einsatz im Kurs

Der LDAP-/AD-Block ist direkt in die [Folien von Modul 07](../slides/07-identity-provider-foederation/slides.md)
integriert. Zwei Gegenproben machen Suchfehler und verzögert sichtbare Gruppenänderungen
im Lab nachvollziehbar.

Die AD-Einheit ist eine optionale Vertiefung für Tag 3. Sie braucht einen vom Trainer
vorbereiteten Windows-Server mit Active Directory auf Google Cloud; ohne Freigabe der
Cloud-Ressourcen bleibt das OpenLDAP-Lab 07c der Ersatz.

Mandantenfähigkeit passt nach Modul 07 oder als Vertiefung an Tag 3. Betriebsübernahme
schließt an die Module 10 und 11 an. Modul 12 bleibt ein eigener Schwerpunkt.

Jedes Planspiel beginnt mit einem fachlichen Einstieg. Zwei Dreiergruppen bearbeiten denselben
Fall, stellen ihre Entwürfe vor und werten die Ergebnisse gemeinsam aus. Dabei dürfen
unterschiedliche Entwürfe entstehen, solange die Gruppen erklären, welche Anforderungen
ihre Entscheidung bestimmen.

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

## Zusatzfälle einsetzen

Die Gruppen bearbeiten zunächst den Hauptfall. Für eine Vertiefung erhalten sie anschließend
den Zusatzfall und passen ihren Entwurf an. Bei der Vorstellung zeigen sie beide Fassungen
und erklären, was sich geändert hat.

## Vorbereitung und Ausgabe

Zur Vorbereitung dienen die Musterarchitektur in der
[Trainerunterlage zur Mandantenfähigkeit](mandantenfaehigkeit/trainer.md) und die beiden
Übertragungsverfahren in der [Trainerunterlage zur Betriebsübernahme](betriebsuebernahme/trainer.md).
Die Zugriffstests und der Rückfallplan enthalten die Fragen, an denen sich die Entwürfe
später prüfen lassen. Für jede Gruppe werden ein Aufgabenblatt und eine Whiteboard-Fläche
oder ein großer Papierbogen benötigt.

Für die beiden Planspiele liegen die Texte direkt im jeweiligen Workshop-Verzeichnis:

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
Für Modul 07 beschreibt das [LDAP-Begleitmaterial](ldap-ad/README.md) den Ablauf und die PDF-Ausgabe.

## Quellen

Die Trainerunterlagen verlinken die verwendete Keycloak-Dokumentation. Die Planspiele
arbeiten mit erfundenen Ausgangslagen. Wer einen Entwurf auf eine reale Installation
überträgt, muss deren Anforderungen prüfen und die Migration an einer Kopie erproben.
