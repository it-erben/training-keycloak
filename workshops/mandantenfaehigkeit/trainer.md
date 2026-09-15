# Trainerunterlage: Mandantenfähigkeit

## Lernziel und Ablauf

Nach der Übung soll die Gruppe erklären können, welche Grenze ein Realm setzt und welche
Zugriffsregeln die Anwendung selbst durchsetzen muss. Der Entwurf unten ist eine mögliche
Lösung. Andere Architekturen sind ebenso brauchbar, wenn sie die Anforderungen des Falls erfüllen.

| Minute | Moderation                                                                  |
| ------ | --------------------------------------------------------------------------- |
| 0-12   | Kurzfolien zeigen; Realm, Organization und Datenbereich unterscheiden       |
| 12-35  | Gruppen arbeiten; nach 10 Minuten nach dem Zugriff auf Dokument 4711 fragen |
| 35-49  | Jede Gruppe stellt sieben Minuten vor                                       |
| 49-60  | Gegenbeispiele prüfen und Unterschiede der Entwürfe besprechen              |

Bitte die Gruppen, eigene Annahmen neben das Diagramm zu schreiben. So lässt sich später
erkennen, ob zwei Entwürfe unterschiedliche Anforderungen lösen. Für die 23 Minuten
Gruppenarbeit helfen 10 Minuten Architektur, 8 Minuten Zugriffstests und 5 Minuten Vorbereitung
der Vorstellung. In der 45-Minuten-Variante genügen Stichpunkte zur Helpdesk-Administration.

## Beispiel: Gemeinsames Portal, getrennte Abrechnung

Ein gemeinsamer Realm `mitarbeiter` passt zum zentralen IAM-Team und zum gewünschten SSO
zwischen Portal und Dokumentenservice. Beide Anwendungen erhalten eigene Clients.
Die zwei Active Directories bleiben als Benutzerquellen erhalten; vor ihrer Anbindung
muss das IAM-Team Namenskollisionen und die Zuordnung der Konten klären.

Für die Abrechnung kommt ein eigener Realm `abrechnung` hinzu. Dort lassen sich Anmeldung
und Konfiguration getrennt verwalten. Die Gruppe darf dasselbe AD anbinden oder einen
gesonderten Benutzerbestand vorsehen, muss aber die Wahl begründen. Zwischen den beiden
Realms besteht nicht automatisch eine gemeinsame SSO-Sitzung.

Für Partner ist eine Organization mit passendem Identity Provider innerhalb des
Mitarbeiter-Realms eine mögliche Lösung. Bei höheren Anforderungen an die Trennung ist
ein Partner-Realm ebenfalls vertretbar. Organizations unterstützen unter anderem
Mitgliedschaften, Einladungen, Identity Brokering und Organisationskontext im Token.
Eine Organization bleibt Teil ihres Realms. Ob sich die Helpdesk-Rechte damit ausreichend
begrenzen lassen, muss die Gruppe als offenen Funktionstest benennen: Ein Nord-Helpdesk
versucht, einen Süd-Benutzer zu verwalten, und muss abgewiesen werden.

Für die internen Bereiche Nord und Süd können Gruppen und anwendungsspezifische Rollen
ausreichen. Organizations kommen vor allem dann in Betracht, wenn deren Einladungen,
IdP-Zuordnung oder Organisationskontext gebraucht werden.

## Vergleich der Alternativen

| Entscheidung          | Vorteil                            | Konsequenz / Grenze                                    |
| --------------------- | ---------------------------------- | ------------------------------------------------------ |
| Gemeinsamer Realm     | Gemeinsame SSO-Basis               | Geteilte Realm-Konfiguration und Verantwortung         |
| Mehrere Realms        | Getrennte Identitätskonfiguration  | Mehr Clients; SSO nicht automatisch gemeinsam          |
| Organizations         | B2B-Kontext innerhalb eines Realms | Anwendung muss Kontext und Objektzugriff prüfen        |
| Gruppen / Rollen      | Fachliche Zugehörigkeit und Rechte | Keine eigene Realm- oder Datengrenze                   |
| Separate Installation | Betrieb kann unabhängig sein       | Mehr Betriebsaufwand; Abhängigkeiten ebenfalls trennen |

Zwei Realms derselben Installation teilen etwa den Keycloak-Prozess, Wartungsfenster und
Datenbankinfrastruktur. Fällt diese Installation aus, können beide Realms betroffen sein.
Auch PCI-DSS-Anforderungen müssen gesondert geprüft werden.

## Identität und mehrere Zugehörigkeiten

Die beiden `alex`-Konten gehören verschiedenen Personen. Damit die Anwendung sie auch nach
dem Umzug in einen gemeinsamen Realm auseinanderhalten kann, braucht es eindeutige
Benutzernamen oder ein Mapping, das die Herkunft des Kontos berücksichtigt. Gleiche Namen
oder E-Mail-Adressen beweisen noch nicht, dass zwei Konten derselben Person gehören.

Anna gehört zu Nord und Süd. Führt die Gruppe ihre Quellkonten zu einer zentralen Identität
zusammen, muss sie erklären, wie das IAM-Team diese Zuordnung bestätigt.
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

Die Aufgabe lässt auch einen unverbindlichen Suchfilter zu. Dann darf Annas Nord-Recht für
den Zugriff ausreichen, obwohl sie `bereich=sued` sendet. Entscheidend ist, dass die Gruppe
diesen API-Vertrag festhält und Oberfläche, Logging und Tests dazu passen. Der Partner
erhält durch einen geänderten Parameter weiterhin keine Nord-Rechte.

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

Prüfe am Diagramm, ob die Gruppe SSO, die beiden `alex`-Konten und den verweigerten
Partnerzugriff erklären kann. Bei einer offenen Produkteinstellung genügt ein genauer
Prüfauftrag mit erwartetem Ergebnis. "Keycloak macht das" ist dafür zu wenig.

Lass zum Schluss jede Gruppe eine geänderte Anforderung nennen, die ihren Entwurf
unbrauchbar machen würde. Im 90-Minuten-Workshop dient dafür der zusätzliche Wunsch von Süd.

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
