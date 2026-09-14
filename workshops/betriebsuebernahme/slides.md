---
marp: true
theme: default
paginate: true
header: "Vertiefung: Betriebsübernahme"
footer: "CC BY-NC-SA 4.0, Alexander Erben"
---

# Vertiefung

## Keycloak vom Dienstleister übernehmen

Planspiel · Keycloak 26.5 · 60 Minuten

---

## Lernziele

Nach diesem Workshop kannst du:

- Fehlende Informationen für eine Betriebsübernahme gezielt anfordern.
- Datenbankübernahme und CLI-Export mit ihren Grenzen einordnen.
- Die Anwendungssicht in Abnahme und Umschaltung berücksichtigen.
- Einen Rückfall einschließlich seiner Datenfolgen planen.

---

## 1. Was wird eigentlich übergeben?

- **Software:** genaue Version, Image, Java-Provider und Theme
- **Identitäten:** Daten, Credentials, Schlüssel und Benutzerquellen
- **Integrationen:** Clients, Secrets, URLs, Claims und Netzzugänge
- **Betrieb:** Datenbank, DNS, TLS, Konfiguration, Monitoring und Wiederherstellung

Welche dieser Informationen findet ihr in einem Realm-Export?

---

## 2. Drei Artefakte, unterschiedlicher Umfang

| Artefakt                     | Wesentliche Grenze                                         |
| ---------------------------- | ---------------------------------------------------------- |
| Export aus der Admin-Konsole | Keine regulären Benutzer; sensible Werte maskiert          |
| CLI-Realm-Export             | Kein vollständiges Betriebsbackup; keine Sitzungsübernahme |
| Konsistentes DB-Backup       | Externe Konfiguration, Provider und Secrets separat nötig  |

Für beide Übertragungswege sind ein vollständiger Bestand und eine Restore-Probe nötig.

---

## 3. Was Anwendungen wiedererkennen müssen

- Öffentlicher Issuer und erwartete Token-Eigenschaften
- Client-IDs, Redirects, Logout-URLs und vertrauliche Client-Secrets
- Prüfschlüssel, Benutzeridentitäten und benötigte Claims
- Erreichbare Endpunkte und externe Identitätsquellen

Ein neuer Kubernetes-Service kann intern anders heißen.
Die öffentliche Identität des Dienstes braucht eine bewusste Entscheidung.

---

## 4. Sitzungen und Rückfall früh entscheiden

- Dürfen sich Benutzer nach der Übernahme neu anmelden müssen?
- Welche Daten können während der Umschaltung noch verändert werden?
- Was passiert mit Änderungen, die nur im Zielsystem existieren?
- Wie lange dauert ein erprobter Rückfall tatsächlich?

Der Keycloak Operator verwaltet keine Datenbanksicherung.

---

## 5. Euer Fall: Mustertech übernimmt

Der Dienstleister liefert bisher nur einen Export aus der Admin-Konsole.

- Ziel: eigener Kubernetes-Cluster; Datenbank separat bereitstellen
- Bestand: Keycloak 26.5.x, AD, lokale Partner, eigenes Theme und Provider
- Anwendungen: SPA, serverseitige Webanwendung, API und Batch-Dienst
- Wartungsfenster: Samstag, 10:00 bis 11:00 Uhr; kein Upgrade verlangt

Die Situation ist fiktiv. Weitere Übergabeinformationen stehen zur Verhandlung.

---

## 6. Gruppenauftrag · 23 Minuten

**Zwei Gruppen mit je drei Personen; Rollen gegenüber dem ersten Workshop wechseln.**

1. Formuliert acht Übergabefragen mit Verantwortlichen und Nachweisen.
2. Wählt ein Verfahren und benennt seine Voraussetzungen.
3. Plant Probe, Abnahme, letzte Datenübernahme und Umschaltung.
4. Definiert mindestens sechs Tests sowie Rückfallkriterien und Entscheider.

Danach stellt jede Gruppe ihren Plan in sieben Minuten vor.

---

## 7. Gegenprüfung und Auswertung

- Welcher Nachweis fehlt euch noch für die Freigabe?
- Welche Anwendung könnte trotz funktionierendem Portal-Login ausfallen?
- Wann fällt die Entscheidung über einen Rückfall?
- Welcher Datenstand gilt anschließend für Benutzer und Anwendungen?

Eine begründete Verschiebung ist ein gültiges Ergebnis.

---

## Zum Nachschlagen

- [Import und Export in Keycloak 26.5.0][export-version]
- [Hostname und öffentliche Endpunkte][hostname]
- [Keycloak Operator und Datenbank][operator]

Aktuelle Betriebsdokumentation gegen die eingesetzte Version prüfen.
Das Planspiel ersetzt keine erprobte Migration der konkreten Installation.

[export-version]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/guides/server/importExport.adoc
[hostname]: https://www.keycloak.org/server/hostname
[operator]: https://www.keycloak.org/operator/basic-deployment
