# Modul 07b: GitHub als Identity Provider mit Domain-basiertem Routing

## Übungsziel

Am Ende dieser Übung hast du:

- Eine **GitHub OAuth App** erstellt und als Identity Provider in Keycloak eingebunden
- Das **Organizations**-Feature aktiviert und eine Organisation mit Domain-Zuordnung konfiguriert
- **Identity-First Login** verstanden: E-Mail-Eingabe bestimmt den Authentifizierungspfad
- Domain-basiertes Routing getestet: `@mustertech.de` → Passwort, andere Domains → GitHub

**Geschätzte Dauer:** 20 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet
- Ein **GitHub-Account** (kostenlos)

### Umgebung starten

```bash
cd assignments/modul-07b-github-idp
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details siehe
> [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

Warte bis alle Services bereit sind (~90 Sekunden). Der Realm "mustertech" wird automatisch
importiert. Prüfe den Setup-Container:

```bash
docker compose logs -f assignment-setup
# -> "=== Setup complete ===" abwarten, dann Ctrl+C
```

### Architektur

```
Browser --> Keycloak (Port 8080) --> PostgreSQL
                |
                +--> GitHub (externer IdP)
```

| Service | URL | Zugangsdaten |
| :--- | :--- | :--- |
| Keycloak Admin-Konsole | <http://localhost:8080> | `admin` / `admin` |
| Keycloak Account Console | <http://localhost:8080/realms/mustertech/account> | Testbenutzer |

### Testbenutzer

| User           | Passwort   | E-Mail                       |
|:---------------|:-----------|:-----------------------------|
| `hans.mueller` | `test1234` | `hans.mueller@mustertech.de` |
| `anna.schmidt` | `test1234` | `anna.schmidt@mustertech.de` |
| `max.admin`    | `test1234` | `max.admin@mustertech.de`    |

---

## Teil 1: GitHub Identity Provider einrichten

### Schritt 1.1: GitHub OAuth App erstellen

1. Öffne <https://github.com/settings/developers>
2. Klicke auf **OAuth Apps** → **New OAuth App**
3. Fülle das Formular aus:

| Feld                       | Wert                                                             |
|:---------------------------|:-----------------------------------------------------------------|
| Application name           | `Keycloak Schulung` (frei wählbar)                               |
| Homepage URL               | `http://localhost:8080`                                          |
| Authorization callback URL | `http://localhost:8080/realms/mustertech/broker/github/endpoint` |

4. Klicke auf **Register application**
5. Notiere die **Client ID**
6. Klicke auf **Generate a new client secret** und notiere das **Client Secret**

> **Woher kommt die Callback URL?** Keycloak verwendet das Muster
> `{server}/realms/{realm}/broker/{idp-alias}/endpoint`. Den Alias legen wir im nächsten
> Schritt als `github` fest.

### Schritt 1.2: Identity Provider in Keycloak anlegen

1. Öffne die Admin-Konsole: <http://localhost:8080>
2. Wähle den Realm **mustertech**
3. Navigiere zu **Identity providers**
4. Klicke auf **Add provider** → **GitHub**
5. Konfiguriere:

| Feld           | Wert                             |
|:---------------|:---------------------------------|
| Alias          | `github` (vorausgefüllt)         |
| Client ID      | Client ID aus Schritt 1.1        |
| Client Secret  | Client Secret aus Schritt 1.1    |

6. Klicke **Save**
7. Scrolle nach unten zu **Advanced settings** und setze:

| Feld           | Wert        |
|:---------------|:------------|
| Trust Email    | **ON**      |

8. Klicke **Save**

> **Trust Email** bedeutet: E-Mail-Adressen, die von GitHub kommen, gelten als verifiziert.
> Ohne diese Einstellung müssten Benutzer ihre E-Mail erneut bestätigen.

### Schritt 1.3: Konfiguration verifizieren

Prüfe auf der IdP-Detailseite:

- **Redirect URI** sollte angezeigt werden als:
  `http://localhost:8080/realms/mustertech/broker/github/endpoint`
- Dies muss mit der **Authorization callback URL** der GitHub OAuth App übereinstimmen

---

## Teil 2: Organizations konfigurieren

### Schritt 2.1: Organizations aktivieren

1. Navigiere zu **Realm settings**
2. Wechsle zum Tab **General**
3. Scrolle zu **Organizations** und setze den Wert auf **Enabled**
4. Klicke **Save**

### Schritt 2.2: Organisation erstellen

1. Navigiere zu **Organizations** (im linken Menü)
2. Klicke auf **Create organization**
3. Fülle aus:

| Feld        | Wert                                              |
|:------------|:--------------------------------------------------|
| Name        | `ExternePartner`                                  |
| Description | `Externe Benutzer, die sich über GitHub anmelden` |

4. Klicke **Save**

### Schritt 2.3: Domain hinzufügen

1. Klicke auf **Add domain**
2. Trage deine **eigene** E-Mail-Domain ein (z.B. `gmail.com`, `outlook.de`, `firma.de`)

> **Wichtig:** Verwende **nicht** `mustertech.de` - diese Domain gehört zu den lokalen
> Benutzern, die sich per Passwort anmelden sollen.

3. Klicke **Save**

### Schritt 2.4: Identity Provider verknüpfen

1. Wechsle zum Tab **Identity providers**
2. Klicke auf **Link identity provider**
3. Wähle **github** aus
4. Konfiguriere die Verknüpfung:

| Feld | Wert |
| :--- | :--- |
| Identity provider | `github` |
| Domain | Dieselbe Domain wie in Schritt 2.3 |
| Redirect when email domain matches | **ON** |

5. Klicke **Save**

> **Wichtig:** Ohne die Einstellung **"Redirect when email domain matches"** werden neue
> Benutzer, die noch kein Keycloak-Konto haben, **nicht** automatisch zu GitHub weitergeleitet.
> Stattdessen erscheint eine Fehlermeldung. Diese Option sorgt dafür, dass auch unbekannte
> Benutzer anhand ihrer E-Mail-Domain zum richtigen IdP geroutet werden.

---

## Teil 3: Identity-First Login verstehen

### Schritt 3.1: Browser Flow analysieren

1. Navigiere zu **Authentication** → **Flows**
2. Suche den Flow **browser**

Keycloak hat den Browser Flow automatisch angepasst, als Organizations aktiviert wurde.
Der Flow enthält jetzt einen **Organization** Step, der domainbasiertes Routing ermöglicht.

### Schritt 3.2: Ablauf verstehen

Der Login-Prozess funktioniert nun so:

```
Benutzer gibt E-Mail ein
        |
        v
Keycloak prüft die Domain
        |
        +---> Domain gehört zu einer Org mit verknüpftem IdP?
        |       JA  --> Redirect zum IdP (GitHub)
        |       NEIN --> Normales Passwort-Formular
        v
```

> **Identity-First Login** bedeutet: Die E-Mail wird **zuerst** abgefragt, bevor
> entschieden wird, wie die Authentifizierung erfolgt. Das ist der Schlüssel zum
> domainbasierten Routing.

---

## Teil 4: Login testen

### Schritt 4.1: Login als lokaler Benutzer

1. Öffne die Account Console: <http://localhost:8080/realms/mustertech/account>
2. Klicke auf **Sign in**
3. Gib die E-Mail ein: `hans.mueller@mustertech.de`
4. Klicke **Next**

**Erwartetes Ergebnis:** Es erscheint ein **Passwort-Formular**. Die Domain `mustertech.de`
gehört zu keiner Organisation, daher wird der lokale Login verwendet.

5. Gib das Passwort ein: `test1234`
6. Klicke **Sign in**

**Erwartetes Ergebnis:** Du bist angemeldet und siehst die Account Console.

7. Melde dich ab (oben rechts → **Sign out**)

### Schritt 4.2: Login mit externer E-Mail

1. Öffne erneut die Account Console: <http://localhost:8080/realms/mustertech/account>
2. Gib deine **eigene E-Mail-Adresse** ein (deren Domain du in Schritt 2.3 hinzugefügt hast)
3. Klicke **Next**

**Erwartetes Ergebnis:** Du wirst zu **GitHub** weitergeleitet! Keycloak hat erkannt, dass
deine E-Mail-Domain zur Organisation "Externe Partner" gehört und leitet dich zum
verknüpften Identity Provider weiter.

4. Melde dich bei GitHub an und autorisiere die App

**Erwartetes Ergebnis:** Du wirst zurück zu Keycloak geleitet. Beim ersten Login wirst du
ggf. aufgefordert, Profilinformationen zu ergänzen. Danach landest du in der Account Console.

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Eine **GitHub OAuth App** erstellt und als IdP in Keycloak konfiguriert
- [x] **Organizations** mit Domain-Zuordnung und IdP-Verknüpfung eingerichtet
- [x] Den **Identity-First Login Flow** verstanden (E-Mail → Domain-Check → Routing)
- [x] Domain-basiertes Routing getestet:
  - `@mustertech.de` → lokaler Passwort-Login
  - Eigene Domain → Redirect zu GitHub
