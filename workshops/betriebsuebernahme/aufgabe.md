# Workshop: Betriebsübernahme

## Übungsziel

Am Ende dieses Workshops hast du:

- Fehlende Daten und Zugänge beim bisherigen Betreiber angefordert
- Ein Verfahren für die Datenübernahme gewählt und dessen Voraussetzungen erklärt
- Abnahme, Umschaltung und Rückfall für eine Betriebsübernahme geplant

**Geschätzte Dauer:** 60 Minuten einschließlich Einstieg und Auswertung.
**Arbeitsform:** Zwei Dreiergruppen, Whiteboard oder Papier. Keine Änderungen an einem Cluster.

## Ausgangslage: Mustertech übernimmt den Betrieb

In diesem erfundenen Fall übernimmt Mustertech den Keycloak-Betrieb von einem Dienstleister.
Das interne Plattformteam hat dafür einen Kubernetes-Cluster mit Keycloak Operator vorbereitet.
Die Datenbank fehlt noch; sie muss separat bereitgestellt werden.

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

Der Dienstleister kann weitere Dateien und Zugänge liefern. Bisher ist jedoch ungeklärt,
ob ihr die Datenbank, privaten Realm-Schlüssel, Secrets und das Custom Image bekommt.
Auch die Zuständigkeit für DNS und Zertifikat steht noch nicht fest.

## Teil 1: Übergabe vervollständigen

Formuliert acht Fragen oder Anforderungen an den Dienstleister. Schreibt jeweils dazu,
wer die Antwort beschafft und woran ihr erkennt, dass der Punkt geklärt ist. Entscheidet außerdem:

- Reicht die vorhandene Datei für die Übernahme?
- Unter welchen Voraussetzungen würdet ihr eine Datenbankübernahme wählen?
- Unter welchen Voraussetzungen würdet ihr einen CLI-Realm-Export wählen?
- Welche Entscheidung zur Behandlung laufender Sitzungen braucht ihr vorab?

Wählt einen Weg und notiert, was dafür vorliegen muss. Stichpunkte und ein Ablaufdiagramm
genügen für die Vorstellung.

## Teil 2: Umschaltung planen

Erstellt einen Ablauf mit diesen Stationen:

1. Vollständige Bestandsaufnahme und gewähltes Übertragungsverfahren
2. Probe in einer isolierten Zielumgebung
3. Abnahme durch Anwendungen und Betrieb
4. Schreibstopp beziehungsweise abgestimmte letzte Datenübernahme
5. Umschaltung und Beobachtung
6. Entscheidung über Abschluss oder Rückfall

Bis wann müsst ihr entscheiden, damit ein Rückfall noch vor 11 Uhr abgeschlossen ist?
Benennt die Person oder Rolle, die diese Entscheidung trifft. Legt auch fest, was mit
Passwortänderungen und anderen Daten passiert, die erst im Zielsystem entstehen.

| Schritt | Verantwortlich | Voraussetzung | Nachweis | Abbruchkriterium |
| ------- | -------------- | ------------- | -------- | ---------------- |
|         |                |               |          |                  |
|         |                |               |          |                  |
|         |                |               |          |                  |
|         |                |               |          |                  |
|         |                |               |          |                  |
|         |                |               |          |                  |

## Teil 3: Abnahme definieren

Formuliert mindestens sechs Tests mit erwarteten Ergebnissen. Deckt damit alle vier
Anwendungstypen, einen verweigerten Zugriff, AD- und lokale Benutzer sowie den Betrieb ab.
Ein laufender Pod allein zeigt noch nicht, ob sich ein Partner mit MFA anmelden kann.

Bereitet eine siebenminütige Vorstellung vor. Zeigt das gewählte Verfahren, zwei
entscheidende offene Punkte, eure Abnahmekriterien und den Rückfallplan.

## Zusatzfall für 90 Minuten

Nach der Umschaltung funktionieren neue Portal-Anmeldungen. Die API lehnt jedoch Tokens
ab, und ein Batch-Dienst erhält keine neuen Tokens. Ein lokaler Partner hat im Ziel
bereits sein Passwort geändert.

Die andere Gruppe fragt nun: "Warum nicht einfach den DNS-Eintrag zurücksetzen?"

Nennt für beide Fehler eine mögliche Ursache und einen Test, mit dem ihr sie prüfen könnt.
Entscheidet dann, ob ihr zurückschaltet und was mit dem neuen Passwort des Partners passiert.
Falls euch dafür Informationen fehlen, sagt genau, welche ihr zuerst beschaffen müsst.
