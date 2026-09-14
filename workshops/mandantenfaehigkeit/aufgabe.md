# Workshop: Mandantenfähigkeit

## Übungsziel

Am Ende dieses Workshops hast du:

- Eine Realm- und Client-Struktur für mehrere Organisationen begründet
- Identitätsverwaltung und Datenzugriff der Anwendung getrennt betrachtet
- Positive und negative Zugriffstests für die gewählte Architektur formuliert

**Geschätzte Dauer:** 60 Minuten einschließlich Einstieg und Auswertung.
**Arbeitsform:** Zwei Dreiergruppen, Whiteboard oder Papier. Kein laufendes Lab erforderlich.

## Ausgangslage: Mustertech wächst zusammen

Die folgende Situation ist fiktiv. Mustertech Nord und Mustertech Süd gehören nach einer
Fusion zur Mustertech GmbH. Beide haben vorerst ein eigenes Active Directory. Die
Benutzerverzeichnisse werden in den nächsten sechs Monaten nicht zusammengelegt.

Das zentrale IAM-Team darf die Identitätsplattform beider Bereiche administrieren.
Regionale Helpdesks dürfen nur Benutzer ihres Bereichs betreuen. Die konkrete Umsetzung
der delegierten Administration muss vor einem produktiven Einsatz geprüft werden.

| Anwendung            | Nutzerkreis                    | Fachliche Regel                               |
| -------------------- | ------------------------------ | --------------------------------------------- |
| Mitarbeiterportal    | Nord und Süd                   | Gemeinsame Anmeldung; eigene Personaldaten    |
| Dokumentenservice    | Nord, Süd und externe Partner  | Dokumente bleiben einem Bereich zugeordnet    |
| Abrechnungsanwendung | Gesondert berechtigte Personen | Eigene Anmeldung mit strengeren Anforderungen |

Für die Abrechnungsanwendung verlangt die Fallvorgabe eine getrennt verwaltbare
Identitätskonfiguration. Eine unabhängige Infrastruktur ist bisher nicht gefordert.

Anna arbeitet für Nord und Süd. Sie muss im Dokumentenservice zwischen beiden Bereichen
wechseln können. Ein externer Partner darf ausschließlich freigegebene Dokumente von
Süd lesen. In beiden Active Directories existiert ein Konto namens `alex`; es handelt
sich um zwei unterschiedliche Personen.

## Teil 1: Architektur wählen

Vergleiche einen gemeinsamen Realm mit mehreren Realms. Berücksichtige Organizations
als mögliche Struktur innerhalb eines Realms sowie Clients, Gruppen und Rollen.

Zeichne Benutzerquellen, Realms, Anwendungen und die Orte der Berechtigungsprüfung.
Beschrifte die Vertrauensbeziehungen. Halte fest:

1. Wo liegen die Grenzen für Benutzer, Konfiguration und Administration?
2. Zwischen welchen Anwendungen soll SSO gelten? Wo ist eine eigene Anmeldung vorgesehen?
3. Wie werden die beiden Personen namens `alex` eindeutig unterschieden?
4. Wie werden Annas zwei Zugehörigkeiten und die Partnerberechtigung abgebildet?
5. Welche Annahme würde euch zur Wahl einer anderen Architektur bewegen?

Eine Identität darf nicht allein anhand einer gleichen E-Mail-Adresse zusammengeführt werden.
Lege einen überprüfbaren Prozess für die Zuordnung von Konten fest.

## Teil 2: Datenzugriff entwerfen

Ein Dokument trägt die Felder `id` und `bereich`. Anna sendet einen Request auf
`GET /dokumente/4711?bereich=sued`. Das Dokument gehört zu Nord.

Beschreibe, welche Informationen die API aus dem geprüften Token und welche sie aus
ihren eigenen Daten benötigt. Entscheide, ob der Request erlaubt ist. Der Parameter
`bereich` ist eine Eingabe des Clients und kann verändert werden.

Ergänze mindestens vier Testfälle:

| Person und Kontext | Angefragtes Objekt | Erwartetes Ergebnis | Begründung / Nachweis |
| ------------------ | ------------------ | ------------------- | --------------------- |
|                    |                    |                     |                       |
|                    |                    |                     |                       |
|                    |                    |                     |                       |
|                    |                    |                     |                       |

## Teil 3: Ergebnis vorstellen

Bereite eine siebenminütige Vorstellung vor: Architektur, zwei bewusste Abwägungen,
ein erlaubter Zugriff und ein abgewehrter Zugriff. Die andere Gruppe prüft, ob eure
Annahmen die Entscheidung tragen und ob sie einen unzulässigen Zugriff findet.

## Zusatzfall für 90 Minuten

Mustertech Süd verlangt künftig eine eigene Betriebsorganisation. Das zentrale IAM-Team
soll Süd weder administrieren noch dessen Ausfallrisiko mitbestimmen können.

Welche Teile eurer Architektur reichen noch? Welche Grenzen müssten zusätzlich auf
Infrastruktur-, Datenbank- und Betriebsebene entstehen? Unterscheide dabei ein separates
Realm von einer unabhängig betriebenen Installation.
