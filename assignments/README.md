# Übungen: Mitarbeiterportal Mustertech GmbH

Diese Übungsserie begleitet dich durch die Keycloak-Schulung. Du baust schrittweise ein
vollständiges Mitarbeiterportal mit zentraler Authentifizierung auf.

## Voraussetzungen

- **Docker Desktop** - installiert und gestartet
- **Browser** - Chrome oder Firefox (für DevTools)
- **Code-Editor** - VS Code empfohlen

## Architektur-Überblick

```
+---------------------------------------------------------------+
|                     Mitarbeiterportal                          |
+---------------------------------------------------------------+
|                                                                |
|   +--------------+     +--------------+     +--------------+  |
|   |   Portal     |     |  Portal-API  |     | Sync-Service |  |
|   |  (React SPA) |---->|  (Express)   |     |  (Express)   |  |
|   |  OIDC+PKCE   |     |    Token     |     |   Client     |  |
|   |  Port 5173   |     |  Validation  |     | Credentials  |  |
|   +--------------+     |  Port 3001   |     +--------------+  |
|          |             +--------------+            |          |
|          |                    |                    |          |
|          v                    v                    v          |
|   +-----------------------------------------------------------+
|   |                      Keycloak                             |
|   |                   Realm: mustertech                       |
|   |                      Port 8080                            |
|   +-----------------------------------------------------------+
|          ^                         |                          |
|          |                         v                          |
|   +--------------+          +--------------+                  |
|   |Management-CLI|          |  PostgreSQL  |                  |
|   | Device Flow  |          |  Port 5432   |                  |
|   +--------------+          +--------------+                  |
|                                                                |
+---------------------------------------------------------------+
```

## Module

Jedes Modul ist eigenständig startbar. Du kannst bei jedem Modul einsteigen - der benötigte
Keycloak-Zustand wird automatisch per Realm-Import hergestellt.

### Modul starten

```bash
cd assignments/modul-XX-thema
docker compose up -d
```

### Modul beenden

```bash
docker compose down -v
```

> **Wichtig:** Beende immer das aktuelle Modul mit `docker compose down -v`, bevor du ein
> anderes startest. Alle Module nutzen dieselben Ports.

### Übersicht

| Modul | Verzeichnis | Thema |
| :--- | :--- | :--- |
| 03 | `modul-03-installation/` | Keycloak + PostgreSQL mit Docker Compose installieren |
| 04 | `modul-04-benutzerverwaltung/` | User, Gruppen, Rollen anlegen |
| 05 | `modul-05-authentifizierung-mfa/` | Custom Auth Flow mit Conditional OTP |
| 06a | `modul-06a-sso-portal/` | React-Portal mit OIDC + PKCE anbinden |
| 06b | `modul-06b-client-management/` | API, CLI und Sync-Service als Clients |
| 07 | `modul-07-identity-provider/` | GitHub als Identity Provider einrichten |
| 08 | `modul-08-authorization/` | Feingranulare Zugriffskontrolle mit Authorization Services |
| 09a | `modul-09a-anpassung-theming/` | Login-Seite mit Firmen-Branding und E-Mail-Templates |
| 09b | `modul-09b-anpassung-apis/` | Admin REST API und Token Introspection |
| 10a | `modul-10a-sicherheit/` | Passwort-Policies, Brute-Force-Schutz, Sessions |
| 10b | `modul-10b-best-practices/` | Produktions-Checkliste und Best Practices |

## Verzeichnisstruktur

```
assignments/
+-- services/                          # Gemeinsame Anwendungen
|   +-- portal-frontend/               # React SPA (OIDC + PKCE)
|   +-- portal-api/                    # Express Backend (Token-Validierung)
|   +-- management-cli/                # CLI-Tool (Device Flow)
|   +-- sync-service/                  # Hintergrund-Service (Client Credentials)
|   +-- keycloak/themes/mustertech/    # Custom Keycloak Theme
+-- modul-03-installation/
|   +-- docker-compose.yml
|   +-- README.md
+-- modul-04-benutzerverwaltung/
|   +-- docker-compose.yml
|   +-- realm-import.json
|   +-- README.md
+-- ...                                # Weitere Module nach gleichem Muster
+-- images/                            # Bilder für Anleitungen
```

## Hilfe bei Problemen

### Container starten nicht

```bash
# Logs prüfen
docker compose logs assignment-keycloak

# Alles zurücksetzen
docker compose down -v
docker compose up -d
```

### Port bereits belegt

Prüfe, ob die Ports 8080, 5432, 5173, 3001 frei sind:

```bash
# macOS / Linux
lsof -i :8080

# Windows PowerShell
netstat -ano | findstr :8080
```

### Keycloak startet langsam

Der erste Start kann 30-60 Sekunden dauern. Prüfe den Status:

```bash
docker compose logs -f assignment-keycloak
# Warten auf: "Running the server in development mode."
```

### Realm-Import funktioniert nicht

Der Realm wird nur beim **ersten Start** importiert. Wenn du den Realm-Import erneut ausführen möchtest:

```bash
docker compose down -v
docker compose up -d
```
