---
marp: true
theme: default
paginate: true
header: "Vertiefung: Mandantenfähigkeit"
footer: "CC BY-NC-SA 4.0, Alexander Erben"
---

# Vertiefung

## Mandantenfähigkeit nach einer Fusion

Architekturworkshop · Keycloak 26.5

---

## Lernziele

Nach diesem Workshop kannst du:

- Realms, Organizations und fachliche Datenbereiche unterscheiden.
- Erklären, warum du einen gemeinsamen oder mehrere Realms wählst.
- Gleichnamige Benutzer und Personen mit mehreren Zugehörigkeiten auseinanderhalten.
- Zeigen, wo eine API unzulässige Objektzugriffe abwehrt.

---

## 1. Welche Grenze brauchen wir?

| Anforderung                       | Zu klärende Entscheidung                         |
| --------------------------------- | ------------------------------------------------ |
| Gemeinsame Anmeldung              | Welche Anwendungen teilen eine SSO-Basis?        |
| Getrennte Identitätskonfiguration | Welche Realm-Grenzen sind nötig?                 |
| Zugehörigkeit und Berechtigung    | Welche Organizations, Gruppen und Rollen passen? |
| Getrennte Geschäftsdaten          | Wo prüft die Anwendung den Objektzugriff?        |

Beginnt bei den gewünschten Zugriffen und Zuständigkeiten.

---

## 2. Realms und Organizations

- Ein **Realm** verwaltet einen eigenen Identitäts- und Konfigurationsbereich.
- Eine **Organization** bildet B2B-Zugehörigkeit innerhalb eines Realms ab.
- Mehrere Realms teilen nicht automatisch dieselbe SSO-Sitzung.
- Mehrere Realms können weiterhin dieselbe Betriebsinfrastruktur teilen.

Testet Helpdesk-Rechte: Kann ein Nord-Helpdesk einen Süd-Benutzer verändern?

---

## 3. Was die Anwendung entscheiden muss

Ein geprüftes Access Token liefert Identität und Berechtigungsangaben.

Die API verknüpft diese mit:

- Dem tatsächlich angefragten Objekt und dessen Bereich
- Den erlaubten Aktionen und fachlichen Freigaben
- Dem aktiven Bereich, falls die Anwendung einen solchen Arbeitskontext vorsieht

Ein veränderbarer Request-Parameter ist kein Berechtigungsnachweis.

---

## 4. Identität ist mehr als ein Benutzername

- Zwei Personen können in verschiedenen Quellen `alex` heißen.
- Eine Person kann für mehrere Bereiche arbeiten.
- Konten werden nur nach überprüfter Zuordnung zusammengeführt.
- Bei mehreren Ausstellern unterscheiden Anwendungen mindestens `iss` und `sub`.

Wie weist ihr nach, dass zwei Quellkonten derselben Person gehören?

---

## 5. Euer Fall: Mustertech Nord und Süd

Zwei bisher getrennte Unternehmen, zwei Active Directories:

- Ein gemeinsames Mitarbeiterportal und ein Dokumentenservice
- Eine Abrechnung mit getrennt verwaltbarer Identitätskonfiguration
- Anna arbeitet für beide Bereiche; ein Partner hat nur einzelne Süd-Freigaben
- Zentrales IAM-Team; regionale Helpdesks betreuen ihren eigenen Bereich

Das Aufgabenblatt beschreibt den vollständigen, erfundenen Fall.

---

## 6. Gruppenauftrag

**Zwei Gruppen mit je drei Personen:** Zeichnen, Entscheidungen festhalten, Gegenbeispiele prüfen.

1. Entwerft Realms, Clients, Benutzerquellen und Berechtigungsprüfung.
2. Erklärt zwei Architekturentscheidungen und die Zuordnung der beiden `alex`-Konten.
3. Legt die Bedeutung von `bereich` fest und prüft Annas Request auf Dokument 4711.
4. Formuliert mindestens vier Tests, einschließlich verweigerter Zugriffe.

Danach stellt jede Gruppe ihren Entwurf vor.

---

## 7. Gegenprüfung und Auswertung

- Wo liegen Identitäts-, Administrations- und Datengrenzen?
- Welche SSO-Erwartung erfüllt der Entwurf?
- Welche Prüfung verhindert einen Zugriff auf den falschen Bereich?
- Welche neue Anforderung würde eure Architektur verändern?

Nennt eine geänderte Anforderung, die euren Entwurf unbrauchbar machen würde.

---

## Zum Nachschlagen

- [Realms in Keycloak 26.5.0][realms]
- [Organizations in Keycloak 26.5.0][organizations]
- [OIDC: Stabilität von Subject und Issuer][oidc]

Aufgabenblatt und Trainerunterlage enthalten den vollständigen Fall und die Auswertung.

[realms]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/server_admin/topics/realms.adoc
[organizations]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/server_admin/topics/organizations/intro.adoc
[oidc]: https://openid.net/specs/openid-connect-core-1_0.html#ClaimStability
