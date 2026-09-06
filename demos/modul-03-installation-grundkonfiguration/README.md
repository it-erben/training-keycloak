# Live-Demo Modul 03: Installation & Grundkonfiguration

Keycloak mit Docker Compose starten, die Admin-Konsole erkunden und den Realm **mustertech** einrichten. Das ist die
Basis für alle folgenden Module.

| Demo   | Thema                             | Dauer |
|:-------|:----------------------------------|:------|
| Demo 1 | Docker Compose starten            | 3 Min |
| Demo 2 | Admin-Konsole erkunden            | 3 Min |
| Demo 3 | Realm "mustertech" anlegen        | 3 Min |
| Demo 4 | Realm-Einstellungen konfigurieren | 3 Min |

## Voraussetzungen

- Docker / Podman (Container-Runtime)

## Setup

```bash
# 1. Keycloak + Postgres starten (Port 9090)
docker compose up -d

# 2. Warten bis Keycloak bereit ist (~30 s)
docker compose logs -f demo-keycloak
# -> "Keycloak ... started in ..." abwarten, dann Ctrl+C
```

Keycloak Admin-Konsole: <http://localhost:9090> (admin / admin)

---

## Demo 1: Docker Compose starten

### Schritt 1: Container starten

```bash
docker compose up -d
```

### Schritt 2: Logs beobachten

```bash
docker compose logs -f demo-keycloak
```

Warte, bis folgende Zeile erscheint:

```text
Keycloak 26.0.0 on JVM (powered by Quarkus) started in Xs.
```

Drücke `Ctrl+C`.

### Schritt 3: Status prüfen

```bash
docker compose ps
```

> **Zeigen:** Zwei Container laufen: `demo-keycloak` und `demo-postgres`. Keycloak startet im `start-dev`-Modus (HTTP,
> keine HTTPS-Pflicht). In Produktion wäre das anders.

**Diskussionspunkte:**

- Was macht `start-dev` anders als `start`?
- Warum PostgreSQL statt der eingebauten H2-Datenbank?

---

## Demo 2: Admin-Konsole erkunden

### Schritt 1: Login

1. Öffne im Browser: <http://localhost:9090>
2. Klicke auf **Administration Console**
3. Login mit `admin` / `admin`

### Schritt 2: Navigation zeigen

| Bereich                | Zweck                                 |
|:-----------------------|:--------------------------------------|
| **Clients**            | Anwendungen, die Keycloak nutzen      |
| **Realm Roles**        | Berechtigungen auf Realm-Ebene        |
| **Users**              | Benutzerkonten                        |
| **Groups**             | Benutzergruppen                       |
| **Realm settings**     | Grundeinstellungen des Realms         |
| **Authentication**     | Login-Flows und Policies              |
| **Identity providers** | Externe Logins (Google, GitHub, etc.) |

> **Zeigen:** Wir sind im **master**-Realm. Dieser dient nur zur Administration. Für Anwendungen legen wir immer einen
> eigenen Realm an.

---

## Demo 3: Realm "mustertech" anlegen

### Schritt 1: Realm erstellen

1. Klicke oben links auf **master** (Realm-Dropdown)
2. Klicke auf **Create realm**
3. Gib ein:

| Feld       | Wert         |
|:-----------|:-------------|
| Realm name | `mustertech` |
| Enabled    | ON           |

4. Klicke auf **Create**

### Schritt 2: SSL-Pflicht deaktivieren (Dev-Modus)

1. Navigiere zu **Realm settings** (linke Navigation)
2. Setze **Require SSL** auf **None**
3. Klicke auf **Save**

> **Zeigen:** In Produktion wäre hier "External requests" oder "All requests" richtig.
> Für unseren lokalen Dev-Modus schalten wir die SSL-Pflicht ab.

### Schritt 3: Display Name setzen

1. Gib ein:
    - **Display name:** `Mustertech GmbH`
    - **HTML Display name:** `<b>Mustertech</b> GmbH`
2. Klicke auf **Save**

> **Zeigen:** Jeder Realm ist vollständig isoliert: eigene User, Clients, Rollen. Der `mustertech`-Realm ist ab jetzt
> unsere Spielwiese für alle weiteren Module.

---

## Demo 4: Realm-Einstellungen konfigurieren

### Schritt 1: Login-Optionen

1. Navigiere zu **Realm settings** --> Tab **Login**
2. Aktiviere:

| Option            | Wert | Bedeutung                    |
|:------------------|:-----|:-----------------------------|
| User registration | ON   | Selbstregistrierung erlauben |
| Forgot password   | ON   | "Passwort vergessen" Link    |
| Remember me       | ON   | "Angemeldet bleiben" Option  |

3. Klicke auf **Save**

### Schritt 2: OIDC Discovery Endpoint zeigen

Öffne im Browser:

```text
http://localhost:9090/realms/mustertech/.well-known/openid-configuration
```

> **Zeigen:** Jeder Realm hat automatisch alle OIDC-Endpunkte. Die Teilnehmer kennen das aus Modul 02, hier sehen sie
> es für ihren eigenen Realm.

**Diskussionspunkte:**

- Welche Endpunkte erkennt ihr aus Modul 02 wieder?
- Warum hat jeder Realm eigene Endpunkte?
- Was wäre der Vorteil eines separaten Realms pro Kunde (Mandantenfähigkeit)?

---

## Ergebnis

Nach dieser Demo:

- Keycloak läuft auf <http://localhost:9090>
- Realm **mustertech** existiert mit Basis-Konfiguration
- Die Umgebung ist bereit für Modul 04 (Clients & Benutzerverwaltung)

## Aufräumen

```bash
docker compose down -v
```
