# AGENTS

## Linting

Dieses Repo verwendet Linter:

- Markdown: `markdownlint-cli2` mit `--fix`, Line Length max 80
- YAML: `yamllint` (extends relaxed, line-length max 140)
- Links: `lychee` mit `--accept 429,200`, `--exclude http://localhost.*`,
  `--exclude-path .npm-cache`, `--max-concurrency 4`, `--retry-wait-time 2`,
  `--timeout 20`, `--cache`

- Lasse nach jeder Änderung `pre-commit` laufen und behebe alle Änderungen
  selbstständig.

## Referenzmaterial

Du findest im Verzeichnis "book" Referenzmaterial für das Thema.
Lese es dir für jede fachliche Änderung durch.

## Sprache

Alle Materialien dieser Schulung sind auf Deutsch zu formulieren bis auf Code,
der immer Englisch ist.

## Format

Alle Folien sind im Marp-Format zu erstellen und in "slides" abzulegen, wobei
jedes Modul ein eigenes Unterverzeichnis erhält und die Folien selbst in einer
Datei "slides.md" im Modulverzeichnis abgelegt werden.

## Thema

Die Schulung in diesem Repository ist "Einführung in Keycloak".

### Beschreibung

Keycloak ist eine Open-Source-Software für Identitäts- und Zugriffsmanagement
(IAM), die von Red Hat entwickelt wurde. Sie ermöglicht es Organisationen,
Single Sign-On (SSO) mit Identity Federation und Social Login zu implementieren,
was bedeutet, dass Benutzer sich mit ihren bestehenden Anmeldeinformationen von
sozialen Netzwerken oder anderen Identitätsanbietern anmelden können.

Das Seminar "Einführung in Keycloak: Grundlagen des Identitäts- und
Zugriffsmanagements" ist aus mehreren Gründen wichtig und nützlich:

- Wachsende Bedeutung von Sicherheit : In einer digitalisierten Welt, in der
  Sicherheitsverletzungen alltäglich sind, ist es entscheidend, dass
  Organisationen ihre Identitäts- und Zugriffsmanagement-Praktiken stärken.
- Komplexität von IAM verstehen : Identitäts- und Zugriffsmanagement kann
  komplex sein. Dieses Seminar hilft, die Konzepte und Best Practices zu
  verstehen, die für die Implementierung einer sicheren und effizienten
  IAM-Strategie erforderlich sind.
- Technische Fähigkeiten erweitern : Die Teilnehmer lernen, wie sie Keycloak
  installieren, konfigurieren und verwalten können, was ihnen hilft, ihre
  technischen Fähigkeiten und ihre berufliche Entwicklung zu fördern.
- Regulatorische Compliance : Mit zunehmenden Datenschutzvorschriften wie der
  GDPR ist es wichtig, dass Organisationen ihre Benutzerdaten und Zugriffsrechte
  ordnungsgemäß verwalten. Keycloak bietet Funktionen, die Compliance
  erleichtern können.
- Single Sign-On (SSO) und Benutzererfahrung : SSO ist eine wesentliche Funktion
  zur Verbesserung der Benutzererfahrung. Durch das Erlernen der Implementierung
  von SSO mit Keycloak können Organisationen ihren Benutzern einen nahtlosen
  Zugang zu verschiedenen Systemen bieten.
- Kostenreduktion und Effizienz : Keycloak als Open-Source-Lösung kann Kosten
  reduzieren, die sonst für kommerzielle IAM-Produkte anfallen würden, und
  gleichzeitig die Effizienz durch Automatisierung und Vereinfachung von
  Authentifizierungsprozessen steigern.
- Anpassung an Unternehmensbedürfnisse : Keycloak ist hochgradig anpassbar. Das
  Seminar vermittelt das nötige Wissen, um Keycloak an die spezifischen
  Bedürfnisse eines Unternehmens anzupassen.
- Zukunftssicherheit und Skalierbarkeit : Keycloak unterstützt moderne
  Protokolle und kann mit wachsenden Benutzerzahlen und sich entwickelnden
  Technologien skalieren, was Organisationen dabei hilft, zukunftssicher zu
  bleiben.

## Modulplan

- Einführung in Keycloak und IAM
  - Definition von IAM und die Rolle von Keycloak
  - Übersicht über die Keycloak-Architektur
  - Vergleich von Keycloak mit anderen IAM-Lösungen
- Installation und Grundkonfiguration
  - Systemanforderungen und Installationsprozess
  - Oberfläche von Keycloak erkunden
  - Erste Schritte mit Realms, Clients und Rollen
- Benutzerverwaltung
  - Benutzererstellung, -bearbeitung und -löschung
  - Benutzerattribute und -rollenverwaltung
  - Benutzergruppen und deren Verwaltung
- Sicherheitsfunktionen
  - Passwortsicherheitsrichtlinien
  - Zwei-Faktor-Authentifizierung
  - Sitzungsmanagement und Anmeldeprotokolle
- Authentifizierungsflüsse
  - Standardflüsse und deren Anpassung
  - Eigene Authentifizierungsflows erstellen
  - OTP und andere Authentifizierungsmechanismen
- Single Sign-On (SSO) konfigurieren
  - Grundlagen von SSO und seine Vorteile
  - SSO mit OpenID Connect und SAML
  - SSO-Sessions und Client-Konfiguration
- Identity Provider und Föderation
  - Einrichten von Identity Providern
  - Benutzerföderation mit LDAP und Active Directory
  - Social Identity Provider wie Google und Facebook integrieren
- Client-Management
  - Client-Typen in Keycloak
  - Zugriffstypen und Servicekonten
  - Client-Scopes und Berechtigungen
- Feingranulare Zugriffskontrolle
  - Rollenbasierte Zugriffskontrolle (RBAC)
  - Attribute Based Access Control (ABAC)
  - Berechtigungen und Ressourcen-Server
- Anpassung und Theming
  - Anpassung von Login-Seiten
  - Eigenes Branding in der Keycloak-Oberfläche
  - Sprachen und Lokalisierung
- Keycloak APIs
  - Übersicht über die Keycloak Admin REST API
  - Benutzerverwaltung über die API
  - Anpassung und Erweiterung von Keycloak durch eigene Provider
- Best Practices und Absicherung
  - Sicherheits-Best Practices für Keycloak
  - Backup und Wiederherstellung von Keycloak-Daten
  - Performance-Tuning und Clustering von Keycloak
