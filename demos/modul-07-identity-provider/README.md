# Live-Demo Modul 07: Identity Provider

Gitea als externen OIDC Identity Provider konfigurieren und den First Login Flow erklären.
Gitea läuft lokal als Container, ein externer Account ist nicht nötig.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Gitea Setup | 2 Min |
| Demo 2 | IdP in Keycloak konfigurieren | 3 Min |
| Demo 3 | Login testen & First Login Flow erklären | 4 Min |

## Voraussetzungen

- Docker / Podman (Container-Runtime)
- curl, python3 (für setup.sh)

## Setup

```bash
# 1. Keycloak + Postgres + Gitea starten
docker compose up -d

# 2. Warten bis Keycloak bereit ist (~30 s)
docker compose logs -f demo-keycloak
# -> "Keycloak ... started in ..." abwarten, dann Ctrl+C

# 3. Gitea User + OAuth2 App anlegen
bash setup.sh
```

Keycloak Admin-Konsole: <http://localhost:9090> (admin / admin)

Gitea: <http://localhost:3000>

---

## Demo 1: Gitea Setup

Das `setup.sh`-Skript hat folgende Dinge automatisch erledigt:

1. Admin-User `gitea-admin` in Gitea erstellt mit Passwort `admin1234`
2. Test-User `alice` / `demo1234` in Gitea erstellt
3. OAuth2-Application "Keycloak Demo" in Gitea registriert

Die Ausgabe des Skripts enthält **Client ID** und **Client Secret**, diese brauchen wir gleich.

> **Zeigen:** Gitea unter <http://localhost:3000> öffnen, als `gitea-admin` einloggen und
> die OAuth2-Application zeigen (Avatar oben rechts -> Settings -> Applications).

---

## Demo 2: IdP in Keycloak konfigurieren

### Schritt 1: Identity Provider hinzufügen

1. In der Admin-Konsole: **Identity providers** -> **Add provider** -> **OpenID Connect v1.0**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Alias | `gitea` |
| Display name | `Gitea` |
| Discovery endpoint | *(leer lassen, siehe Hinweis)* |
| Authorization URL | `http://localhost:3000/login/oauth/authorize` |
| Token URL | `http://demo-gitea:3000/login/oauth/access_token` |
| Client ID | *Client ID aus setup.sh* |
| Client Secret | *Client Secret aus setup.sh* |
| Default Scopes | `openid profile email` |

3. Klicke auf **Save**

> **Hinweis: Warum kein Discovery?**
> Gitea's Discovery-Dokument liefert alle URLs mit `localhost:3000` (der `ROOT_URL`).
> Die Authorization URL wird vom **Browser** aufgerufen, `localhost` funktioniert.
> Die Token URL wird aber **server-seitig von Keycloak** aufgerufen, und innerhalb von
> Docker ist `localhost` der Keycloak-Container selbst.
> Deshalb setzen wir die Token URL manuell auf `http://demo-gitea:3000/...` (Docker-Netzwerkname).

### Schritt 2: Redirect URI prüfen

Nach dem Speichern zeigt Keycloak die **Redirect URI** an:

```text
http://localhost:9090/realms/mustertech/broker/gitea/endpoint
```

Diese wurde bereits beim Erstellen der OAuth2-App in Gitea hinterlegt.

**Diskussionspunkte:**

- Warum funktioniert Discovery in Produktionsumgebungen problemlos? (Einheitlicher Hostname, kein Docker-Split)
- Was ist der Unterschied zwischen einem Social Provider (GitHub, Google) und einem generischen OIDC-Provider?
- Wann nutzt man Social Login vs. Enterprise IdP (Azure AD, Gitea)?

---

## Demo 3: Login testen & First Login Flow

### Schritt 1: Login-Seite öffnen

1. Öffne ein **Inkognito-Fenster**
2. Navigiere zu: <http://localhost:9090/realms/mustertech/account>
3. Klicke auf **Sign in**

### Schritt 2: "Login with Gitea" klicken

1. Auf der Login-Seite erscheint jetzt ein Button **Gitea**
2. Klicke darauf
3. Gitea fragt nach Autorisierung -> **Authorize**
4. Keycloak zeigt die **"Update Account Information"**-Seite (First Login Flow)

> **Zeigen:** Beim ersten Login über einen externen IdP greift der **First Broker Login Flow**. Keycloak:
>
> 1. Prüft, ob ein lokaler User mit derselben E-Mail existiert
> 2. Wenn nein: Erstellt einen "Schatten-User" und übernimmt die Profildaten
> 3. Lässt den User die Daten bestätigen/ergänzen

### Schritt 3: Profil bestätigen

1. Prüfe die vorausgefüllten Felder (Username, E-Mail)
2. Klicke auf **Submit**

### Schritt 4: User in Admin Console prüfen

1. Wechsle zur Admin-Konsole
2. **Users** -> Suche den neuen User
3. Öffne den User -> Tab **Identity provider links**

> **Zeigen:** Der User hat einen **Identity Provider Link** zu Gitea. Bei zukünftigen
> Logins wird er automatisch verbunden, ohne erneute Profil-Bestätigung.

**Diskussionspunkte:**

- Was passiert, wenn die E-Mail bereits einem lokalen User gehört?
- Kann ein User mehrere IdP-Links haben (z.B. Gitea + Google)?
- Wie kann man den First Login Flow anpassen? (z.B. automatisch erstellen ohne Review)

---

## Aufräumen

```bash
docker compose down -v
```
