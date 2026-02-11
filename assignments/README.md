# Übungen: Mitarbeiterportal Mustertech GmbH

Diese Übungsserie begleitet Sie durch die Keycloak-Schulung. Sie bauen schrittweise ein vollständiges Mitarbeiterportal mit zentraler Authentifizierung auf.

## Voraussetzungen

- **Docker Desktop** (Windows) - installiert und gestartet
- **Node.js 20+** - für Frontend und Backend-Entwicklung
- **Code-Editor** - VS Code empfohlen
- **Browser** - Chrome oder Firefox (für DevTools)

## Architektur-Überblick

```
┌─────────────────────────────────────────────────────────────────┐
│                     Mitarbeiterportal                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐   │
│   │   Portal     │     │  Portal-API  │     │ Sync-Service │   │
│   │  (React SPA) │────▶│  (Express)   │     │  (Express)   │   │
│   │  OIDC+PKCE   │     │    Token     │     │   Client     │   │
│   │  Port 5173   │     │  Validation  │     │ Credentials  │   │
│   └──────────────┘     │  Port 3001   │     └──────────────┘   │
│          │             └──────────────┘            │           │
│          │                    │                    │           │
│          ▼                    ▼                    ▼           │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                      Keycloak                           │  │
│   │                   Realm: mustertech                     │  │
│   │                      Port 8080                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│          ▲                         │                           │
│          │                         ▼                           │
│   ┌──────────────┐          ┌──────────────┐                   │
│   │  Admin-CLI   │          │  PostgreSQL  │                   │
│   │ Device Flow  │          │  Port 5432   │                   │
│   └──────────────┘          └──────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Übungen nach Modul

| Modul | Thema | Beschreibung |
| :--- | :--- | :--- |
| 03 | Installation | Keycloak + PostgreSQL mit Docker Compose |
| 04 | Benutzerverwaltung | User, Gruppen, Rollen anlegen |
| 05 | Sicherheit | MFA, Passwort-Policies, Brute-Force |
| 06 | Auth-Flows | Custom Browser Flow mit Conditional OTP |
| 07 | SSO | React-Portal mit OIDC + PKCE |
| 08 | Identity Provider | GitHub Social Login |
| 09 | Clients | API, CLI, Sync-Service anbinden |
| 10 | Authorization | Feingranulare Zugriffskontrolle |
| 11 | Theming | Login-Seite mit Firmen-Branding |
| 12 | APIs | Admin REST API nutzen |
| 13 | Produktion | Best Practices, HTTPS, Backup |

## Checkpoints

Falls Sie bei einem Modul einsteigen möchten oder Probleme haben, finden Sie im Ordner `checkpoints/` fertige Stände nach jedem Modul.

**Checkpoint verwenden:**

```bash
# Aktuellen Stand sichern (optional)
cp -r . ../backup-mein-stand

# Checkpoint laden
cp -r checkpoints/modul-XX/* .

# Container neu starten
docker compose down -v
docker compose up -d
```

## Schnellstart

```bash
# 1. Umgebungsvariablen kopieren
cp .env.example .env

# 2. Container starten
docker compose up -d

# 3. Keycloak öffnen
# http://localhost:8080
# Login: admin / admin
```

## Hilfe bei Problemen

### Container starten nicht

```bash
# Logs prüfen
docker compose logs keycloak

# Alles zurücksetzen
docker compose down -v
docker compose up -d
```

### Port bereits belegt

Prüfen Sie, ob die Ports 8080, 5432, 5173, 3001 frei sind:

```bash
# Windows PowerShell
netstat -ano | findstr :8080
```

### Keycloak startet langsam

Der erste Start kann 30-60 Sekunden dauern. Prüfen Sie den Status:

```bash
docker compose logs -f keycloak
# Warten auf: "Running the server in development mode."
```
