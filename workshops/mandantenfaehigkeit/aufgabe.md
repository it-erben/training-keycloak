# Workshop: Mandantenfähigkeit

## Übungsziel

Am Ende dieses Workshops hast du:

- Eine Realm- und Client-Struktur für mehrere Organisationen begründet
- Identitätsverwaltung und Datenzugriff der Anwendung getrennt betrachtet
- Positive und negative Zugriffstests für die gewählte Architektur formuliert

**Arbeitsform:** Zwei Dreiergruppen, Whiteboard oder Papier. Kein laufendes Lab erforderlich.

## Ausgangslage: Mustertech wächst zusammen

Im folgenden erfundenen Fall fusionieren Mustertech Nord und Mustertech Süd zur
Mustertech GmbH. Beide behalten für mindestens sechs Monate ihr eigenes Active Directory.

Das zentrale IAM-Team darf die Identitätsplattform beider Bereiche administrieren.
Regionale Helpdesks dürfen nur Benutzer ihres Bereichs betreuen. Haltet fest, wie ihr
später testen würdet, dass ein Helpdesk diese Grenze tatsächlich einhält.

| Anwendung            | Nutzerkreis                    | Fachliche Regel                               |
| -------------------- | ------------------------------ | --------------------------------------------- |
| Mitarbeiterportal    | Nord und Süd                   | Gemeinsame Anmeldung; eigene Personaldaten    |
| Dokumentenservice    | Nord, Süd und externe Partner  | Dokumente bleiben einem Bereich zugeordnet    |
| Abrechnungsanwendung | Gesondert berechtigte Personen | Eigene Anmeldung mit strengeren Anforderungen |

Die Abrechnungsanwendung braucht eine eigene, getrennt verwaltbare Identitätskonfiguration.
Sie darf dieselbe Infrastruktur wie das Portal nutzen.

Anna arbeitet für Nord und Süd. Sie muss im Dokumentenservice zwischen beiden Bereichen
wechseln können. Ein externer Partner darf ausschließlich freigegebene Dokumente von
Süd lesen. In beiden Active Directories existiert ein Konto namens `alex`; es handelt
sich um zwei unterschiedliche Personen.

## Teil 1: Architektur wählen

Vergleicht einen gemeinsamen Realm mit mehreren Realms. Überlegt, wofür ihr Organizations,
Clients, Gruppen und Rollen einsetzen würdet. Ihr müsst nicht jedes dieser Mittel verwenden.

Zeichnet die Benutzerquellen, Realms und Anwendungen. Markiert, wer wem vertraut und wer
den Zugriff auf ein Dokument prüft. Beantwortet dabei:

1. Wo liegen die Grenzen für Benutzer, Konfiguration und Administration?
2. Zwischen welchen Anwendungen soll SSO gelten? Wo ist eine eigene Anmeldung vorgesehen?
3. Wie werden die beiden Personen namens `alex` eindeutig unterschieden?
4. Wie werden Annas zwei Zugehörigkeiten und die Partnerberechtigung abgebildet?
5. Welche Annahme würde euch zur Wahl einer anderen Architektur bewegen?

Beschreibt, wie ihr feststellt, ob zwei Quellkonten derselben Person gehören.
Eine übereinstimmende E-Mail-Adresse allein genügt dafür nicht.

## Teil 2: Datenzugriff entwerfen

Ein Dokument trägt die Felder `id` und `bereich`. Anna sendet einen Request auf
`GET /dokumente/4711?bereich=sued`. Das Dokument gehört zu Nord.

Legt zuerst fest, was `bereich` in eurer API bedeutet: Begrenzt er den aktuellen
Arbeitskontext, oder ist er nur ein Suchfilter? Beschreibt dann, welche Angaben die API
aus dem geprüften Token und welche sie aus ihren eigenen Daten verwendet. Entscheidet,
ob Annas Request erlaubt ist, und begründet das anhand eurer Regel.

Der Client kann `bereich` beliebig verändern. Prüft euren Entwurf deshalb auch mit dem
Partnerkonto, das keine Nord-Rechte besitzt.

Ergänzt mindestens vier Testfälle:

| Person und Kontext | Angefragtes Objekt | Erwartetes Ergebnis | Begründung / Nachweis |
| ------------------ | ------------------ | ------------------- | --------------------- |
|                    |                    |                     |                       |
|                    |                    |                     |                       |
|                    |                    |                     |                       |
|                    |                    |                     |                       |

## Teil 3: Ergebnis vorstellen

Zeigt die Architektur und erklärt an zwei
Stellen, warum ihr euch so entschieden habt. Führt dann einen erlaubten und einen
verweigerten Zugriff durch das Diagramm. Die andere Gruppe versucht, einen Weg zu einem
Dokument zu finden, auf das sie keinen Zugriff haben dürfte.

## Zusatzfall

Mustertech Süd verlangt künftig eine eigene Betriebsorganisation. Das zentrale IAM-Team
soll Süd weder administrieren noch dessen Ausfallrisiko mitbestimmen können.

Was müsstet ihr dafür an Infrastruktur, Datenbank und Betriebszugängen ändern?
Erklärt, welche Forderungen ein weiterer Realm erfüllt und wofür Süd eine unabhängig
betriebene Installation braucht.
