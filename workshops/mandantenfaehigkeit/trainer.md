# Trainerunterlage: Mandantenfähigkeit

## Lernziel und Ablauf

Die Gruppe soll begründen können, welche Trennung ein Realm, eine Organization und die
Anwendung selbst leisten. Eine sorgfältig begründete Alternative ist eine gültige Lösung.
Die Übung bewertet Architekturentscheidungen, nicht die Anzahl angelegter Realms.

| Minute | Moderation                                                                  |
| ------ | --------------------------------------------------------------------------- |
| 0-12   | Kurzfolien zeigen; Realm, Organization und Datenbereich unterscheiden       |
| 12-35  | Gruppen arbeiten; nach 10 Minuten nach dem Zugriff auf Dokument 4711 fragen |
| 35-49  | Jede Gruppe stellt sieben Minuten vor                                       |
| 49-60  | Gegenbeispiele prüfen und Unterschiede der Entwürfe besprechen              |

Die Fallvorgaben stehen vollständig im Aufgabenblatt. Zusätzliche Annahmen der Gruppen
müssen sichtbar notiert werden. Bei 45 Minuten den Zusatzfall und ausführliche
Administrationsdetails weglassen.

## Eine tragfähige Musterarchitektur

Unter der Annahme eines zentralen IAM-Teams ist ein gemeinsamer Realm `mitarbeiter`
für Nord und Süd plausibel. Die vorhandenen Benutzerquellen bleiben angebunden; die
Identitäten werden vor der produktiven Übernahme eindeutig zugeordnet. Portal und
Dokumentenservice erhalten eigene Clients. SSO kann innerhalb dieses Realms genutzt werden.

Die Abrechnungsanwendung erhält gemäß Fallvorgabe einen eigenen Realm `abrechnung`.
Dort werden Anmeldung und Konfiguration getrennt verantwortet. Ob dasselbe AD angebunden
wird oder ein gesonderter Identitätsbestand nötig ist, bleibt eine fachliche Entscheidung.
Eine automatische gemeinsame SSO-Sitzung über beide Realms wird nicht vorausgesetzt.

Für Partner ist eine Organization mit passendem Identity Provider innerhalb des
Mitarbeiter-Realms eine mögliche Lösung. Bei höheren Anforderungen an die Trennung ist
ein Partner-Realm ebenfalls vertretbar. Organizations unterstützen unter anderem
Mitgliedschaften, Einladungen, Identity Brokering und Organisationskontext im Token.
Sie sind keine eigenen Realms. Ihre Eignung für den konkreten Delegationsbedarf muss
mit den verfügbaren Funktionen der eingesetzten Version geprüft werden.

Nord und Süd müssen nicht allein wegen ihrer Namen als Organizations modelliert werden.
Für rein interne Strukturen können Gruppen und anwendungsspezifische Rollen ausreichen.
Die Wahl hängt insbesondere vom Onboarding, den Identitätsquellen und der Administration ab.

## Vergleich der Alternativen

| Entscheidung          | Vorteil                            | Konsequenz / Grenze                                    |
| --------------------- | ---------------------------------- | ------------------------------------------------------ |
| Gemeinsamer Realm     | Gemeinsame SSO-Basis               | Geteilte Realm-Konfiguration und Verantwortung         |
| Mehrere Realms        | Getrennte Identitätskonfiguration  | Mehr Clients; SSO nicht automatisch gemeinsam          |
| Organizations         | B2B-Kontext innerhalb eines Realms | Anwendung muss Kontext und Objektzugriff prüfen        |
| Gruppen / Rollen      | Fachliche Zugehörigkeit und Rechte | Keine eigene Realm- oder Datengrenze                   |
| Separate Installation | Betrieb kann unabhängig sein       | Mehr Betriebsaufwand; Abhängigkeiten ebenfalls trennen |

Zwei Realms in derselben Installation teilen weiterhin etwa Prozess, Wartung und
Datenbankinfrastruktur. Eine Realm-Trennung allein belegt keine unabhängige Ausfallsicherheit.
Sie belegt auch für sich keine Erfüllung von PCI-DSS-Anforderungen.

## Identität und mehrere Zugehörigkeiten

Die beiden `alex`-Konten bleiben verschiedene Personen. Ein Zielkonzept braucht eindeutige
Benutzernamen beziehungsweise ein kontrolliertes Mapping und die Herkunft der Identität.
Gleiche Namen oder E-Mail-Adressen sind kein ausreichender Nachweis derselben Person.

Anna bekommt eine nachvollziehbare Zugehörigkeit zu Nord und Süd. Eine zentrale
Identität ist nur dann passend, wenn die Zuordnung ihrer Quellkonten geprüft wurde.
Ein bewusst gewählter aktiver Bereich begrenzt die aktuelle Arbeitssitzung oder den
Request. Die API prüft sowohl Annas Berechtigung als auch den Bereich des Objekts.
Bei mehreren akzeptierten Realms muss die Anwendung Identitäten mindestens anhand von
Aussteller und Subject (`iss`, `sub`) unterscheiden.

## Musterlösung zum Dokumentenzugriff

Für diese Musterlösung gilt: Der aktive Bereich begrenzt den Request. Anna hat zwar
Zugriff auf Nord und Süd, darf ein Nord-Dokument aber nur im Nord-Kontext abrufen.

Die API prüft das Access Token einschließlich Signatur, Aussteller, Gültigkeit und
vorgesehenem Empfänger. Sie bestimmt erlaubte Bereiche und Rechte aus vertrauenswürdigen
Claims beziehungsweise ihrer eigenen Berechtigungsverwaltung. Dann lädt sie die
Objektzuordnung aus der Datenbank. Der Query-Parameter ersetzt diese Prüfung nicht.

| Person / Kontext | Objekt                                | Ergebnis  | Grund                                         |
| ---------------- | ------------------------------------- | --------- | --------------------------------------------- |
| Anna / Nord      | Nord-Dokument 4711                    | Erlaubt   | Zugehörigkeit, Recht und Objektkontext passen |
| Anna / Süd       | Nord-Dokument 4711                    | Abgelehnt | Aktiver Kontext passt nicht zum Objekt        |
| Partner / Süd    | Freigegebenes Süd-Dokument            | Erlaubt   | Explizite Freigabe und Kontext passen         |
| Partner / Süd    | Nord-Dokument 4711                    | Abgelehnt | Keine Nord-Rechte; Parameter hilft nicht      |
| Anna / Nord      | Nord-Dokument, falsche Token-Audience | Abgelehnt | Token ist nicht für diese API bestimmt        |

Eine alternative Lösung ohne aktiven Kontext ist zulässig, wenn Anna beide Bereiche
bewusst nutzen darf und die API jeden Objektzugriff entsprechend prüft. Sie muss in
Oberfläche, Logging und Tests konsistent sein. Der Partner erhält dadurch keine Nord-Rechte.

## Hilfen und Rückfragen

Wenn die Gruppe nicht weiterkommt, nacheinander fragen:

1. "Wer soll welche Identitätskonfiguration administrieren dürfen?"
2. "Welcher Aussteller steht bei den Anwendungen im Token?"
3. "An welcher Stelle wird geprüft, wem Dokument 4711 gehört?"
4. "Kann ein Teilnehmer den Bereich im Request selbst ändern?"

Bei "ein Realm pro Anwendung" nach dem Nutzen der zusätzlichen Grenze fragen.
Bei "ein Realm pro Firma ist immer richtig" Anna und das gemeinsame Portal einbringen.
Bei "Organization erledigt die Trennung" die konkrete API-Prüfung zeigen lassen.

Für den Zusatzfall reicht ein weiterer Realm nicht aus, wenn das gemeinsame IAM-Team
keinen administrativen Zugriff mehr haben darf oder unabhängiger Betrieb gefordert ist.
Dann sind unter anderem Admin-Zugänge, Datenbank, Secrets, Backups und gemeinsame
Infrastrukturabhängigkeiten separat zu betrachten.

## Abschluss und Bewertung

Eine tragfähige Lösung benennt die Grenzen, erklärt die SSO-Folgen, behandelt die
Identitätskollision und enthält mindestens einen negativen Zugriffstest. Fehlende
Produkteinstellungen dürfen als konkrete Prüfaufträge stehen bleiben. Unbegründete
Sicherheitsversprechen sind keine Lösung.

Zum Abschluss jede Gruppe einen Satz vervollständigen lassen:
"Unsere Architektur passt, solange ...; wir würden sie ändern, wenn ..."

## Fachliche Quellen

Die versionsgebundenen Quellen beziehen sich auf Keycloak 26.5.0. Die aktuelle
Administrationsdokumentation dient zum Nachschlagen; ihre UI kann davon abweichen.

- [Realms, Keycloak 26.5.0][realms]
- [Organizations, Keycloak 26.5.0][organizations]
- [OIDC Core: Subject und Issuer][oidc]
- [Aktuelles Administrationshandbuch][admin]

[realms]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/server_admin/topics/realms.adoc
[organizations]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/server_admin/topics/organizations/intro.adoc
[oidc]: https://openid.net/specs/openid-connect-core-1_0.html#ClaimStability
[admin]: https://www.keycloak.org/docs/latest/server_admin/index.html
