# Workshop: Betriebsübernahme

## Übungsziel

Am Ende dieses Workshops hast du:

- Die benötigten Übergabeinformationen einer Keycloak-Installation benannt
- Eine Übertragungsmethode mit Voraussetzungen gewählt
- Abnahme, Umschaltung und Rückfall für eine Betriebsübernahme geplant

**Geschätzte Dauer:** 60 Minuten einschließlich Einstieg und Auswertung.
**Arbeitsform:** Zwei Dreiergruppen, Whiteboard oder Papier. Keine Änderungen an einem Cluster.

## Ausgangslage: Mustertech übernimmt den Betrieb

Die folgende Situation ist fiktiv. Ein Dienstleister betreibt Keycloak für Mustertech.
Künftig soll das interne Plattformteam den Dienst auf seinem Kubernetes-Cluster betreiben.
Ein Keycloak Operator ist vorhanden. Die Datenbank muss separat bereitgestellt werden.

| Merkmal               | Bekannter Stand                                             |
| --------------------- | ----------------------------------------------------------- |
| Keycloak              | 26.5.x; genaue Patchversion und Image-Digest noch offen     |
| Öffentlicher Hostname | `login.mustertech.example`                                  |
| Realm                 | `mitarbeiter`                                               |
| Anwendungen           | Portal (SPA), serverseitige Webanwendung, API, Batch-Dienst |
| Benutzer              | Active Directory; lokale Partnerkonten mit MFA              |
| Anpassungen           | Eigenes Login-Theme und ein Java-Provider                   |
| Verfügbares Artefakt  | `realm-export.json` aus der Admin-Konsole                   |
| Mögliches Zeitfenster | Samstag, 10:00 bis 11:00 Uhr                                |

Neue Anmeldungen dürfen im angekündigten Zeitfenster kurzzeitig ausfallen. Ob laufende
Sitzungen erhalten bleiben müssen, wurde noch nicht entschieden. Ein Versionsupgrade
ist für die Betriebsübernahme nicht verlangt.

Der Dienstleister kann weitere Artefakte bereitstellen. Zugriff auf die Datenbank,
private Realm-Schlüssel, Secrets und das Custom Image muss aber ausdrücklich geklärt werden.
Die Kontrolle über den öffentlichen Hostnamen und das Zertifikat ist ebenfalls offen.

## Teil 1: Übergabe vervollständigen

Formuliere acht konkrete Fragen beziehungsweise Anforderungen an den Dienstleister.
Ordne jede einem Verantwortlichen und einem Nachweis zu. Entscheide außerdem:

- Reicht die vorhandene Datei für die Übernahme?
- Unter welchen Voraussetzungen würdet ihr eine Datenbankübernahme wählen?
- Unter welchen Voraussetzungen würdet ihr einen CLI-Realm-Export wählen?
- Welche Entscheidung zur Behandlung laufender Sitzungen braucht ihr vorab?

Die Gruppen dürfen unterschiedliche Wege wählen. Jede Voraussetzung muss benannt sein.
Stichpunkte und ein Ablaufdiagramm genügen; ein ausgearbeitetes Betriebshandbuch ist nicht nötig.

## Teil 2: Umschaltung planen

Erstellt einen Ablauf mit diesen Stationen:

1. Vollständige Bestandsaufnahme und gewähltes Übertragungsverfahren
2. Probe in einer isolierten Zielumgebung
3. Abnahme durch Anwendungen und Betrieb
4. Schreibstopp beziehungsweise abgestimmte letzte Datenübernahme
5. Umschaltung und Beobachtung
6. Entscheidung über Abschluss oder Rückfall

Legt einen spätesten Entscheidungspunkt im Zeitfenster fest. Benennt, wer entscheiden
darf. Plant ein, wie Datenänderungen nach der Umschaltung einen Rückfall beeinflussen.

| Schritt | Verantwortlich | Voraussetzung | Nachweis | Abbruchkriterium |
| ------- | -------------- | ------------- | -------- | ---------------- |
|         |                |               |          |                  |
|         |                |               |          |                  |
|         |                |               |          |                  |
|         |                |               |          |                  |

## Teil 3: Abnahme definieren

Mindestens sechs Prüfungen müssen über "Pod ist grün" hinausgehen. Berücksichtige alle
vier Anwendungstypen, einen verweigerten Zugriff, die Benutzerquellen und den Betrieb.

Bereitet eine siebenminütige Vorstellung vor. Zeigt das gewählte Verfahren, zwei
entscheidende offene Punkte, eure Abnahmekriterien und den Rückfallplan.

## Zusatzfall für 90 Minuten

Nach der Umschaltung funktionieren neue Portal-Anmeldungen. Die API lehnt jedoch Tokens
ab, und ein Batch-Dienst erhält keine neuen Tokens. Ein lokaler Partner hat im Ziel
bereits sein Passwort geändert.

Die andere Gruppe fragt nun: "Warum nicht einfach den DNS-Eintrag zurücksetzen?"

Formuliert überprüfbare Hypothesen für die beiden technischen Fehler. Entscheidet, welche
Informationen ihr vor einem Rückfall benötigt und wie ihr die Passwortänderung behandelt.
Begründet eine Entscheidung, ohne einen nicht getesteten Zustand als sicher anzunehmen.
