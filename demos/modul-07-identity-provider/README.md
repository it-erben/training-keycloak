# Live-Demo: Modul 07 — Identity Provider

GitHub als externen Identity Provider konfigurieren und den First Login Flow erklären — der Trainer zeigt das Ergebnis vorab, bevor die Teilnehmer es in der Übung selbst einrichten.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | GitHub OAuth App anlegen | 3 Min |
| Demo 2 | IdP in Keycloak konfigurieren | 3 Min |
| Demo 3 | Login testen & First Login Flow erklären | 4 Min |

## Voraussetzungen

- Keycloak läuft (Realm **mustertech** existiert)
- Admin-Konsole erreichbar unter <http://localhost:8080>
- GitHub-Account des Trainers vorhanden
- **Vorab empfohlen:** GitHub OAuth App bereits angelegt (spart Zeit in der Demo)

---

## Demo 1: GitHub OAuth App anlegen

> **Hinweis:** Dieser Schritt kann vorab erledigt werden. In der Demo zeigt der Trainer die bereits angelegte App und erklärt die Felder.

### Schritt 1 — GitHub Developer Settings öffnen

1. Navigiere zu GitHub → **Settings** → **Developer settings** → **OAuth Apps**
2. Klicke auf **New OAuth App**

### Schritt 2 — OAuth App konfigurieren

| Feld | Wert |
| :--- | :--- |
| Application name | `Keycloak Demo` |
| Homepage URL | `http://localhost:8080` |
| Authorization callback URL | `http://localhost:8080/realms/mustertech/broker/github/endpoint` |

3. Klicke auf **Register application**
4. Klicke auf **Generate a new client secret**
5. **Kopiere Client ID und Client Secret**

> **Zeigen:** Die Callback-URL folgt einem festen Schema: `{keycloak-url}/realms/{realm}/broker/{provider-alias}/endpoint`. Keycloak erwartet den Redirect genau auf diese URL.

---

## Demo 2: IdP in Keycloak konfigurieren

### Schritt 1 — Identity Provider hinzufügen

1. In der Admin-Konsole: **Identity providers** → **Add provider** → **GitHub**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Alias | `github` (vorausgefüllt) |
| Client ID | *Client ID aus GitHub* |
| Client Secret | *Client Secret aus GitHub* |

3. Klicke auf **Save**

### Schritt 2 — Redirect URI prüfen

Nach dem Speichern zeigt Keycloak die **Redirect URI** an. Diese muss mit der Callback URL in GitHub übereinstimmen:

```text
http://localhost:8080/realms/mustertech/broker/github/endpoint
```

> **Zeigen:** Die Redirect URI wird automatisch generiert. Falls sie nicht zur GitHub-App passt, gibt es einen Fehler beim Login.

**Diskussionspunkte:**

- Was ist der Unterschied zwischen GitHub (Social Login) und einem generischen OIDC-Provider?
- Wann nutzt man Social Login vs. Enterprise IdP (Azure AD)?

---

## Demo 3: Login testen & First Login Flow

### Schritt 1 — Login-Seite öffnen

1. Öffne ein **Inkognito-Fenster**
2. Navigiere zu: <http://localhost:8080/realms/mustertech/account>
3. Klicke auf **Sign in**

### Schritt 2 — "Login with GitHub" klicken

1. Auf der Login-Seite erscheint jetzt ein Button **GitHub**
2. Klicke darauf
3. GitHub fragt nach Autorisierung → **Authorize**
4. Keycloak zeigt die **"Update Account Information"**-Seite (First Login Flow)

> **Zeigen:** Beim ersten Login über einen externen IdP greift der **First Broker Login Flow**. Keycloak:
>
> 1. Prüft, ob ein lokaler User mit derselben E-Mail existiert
> 2. Wenn nein: Erstellt einen "Schatten-User" und übernimmt die Profildaten
> 3. Lässt den User die Daten bestätigen/ergänzen

### Schritt 3 — Profil bestätigen

1. Prüfe die vorausgefüllten Felder (Username, E-Mail)
2. Klicke auf **Submit**

### Schritt 4 — User in Admin Console prüfen

1. Wechsle zur Admin-Konsole
2. **Users** → Suche den neuen User
3. Öffne den User → Tab **Identity provider links**

> **Zeigen:** Der User hat einen **Identity Provider Link** zu GitHub. Bei zukünftigen Logins wird er automatisch verbunden — ohne erneute Profil-Bestätigung.

**Diskussionspunkte:**

- Was passiert, wenn die E-Mail bereits einem lokalen User gehört?
- Kann ein User mehrere IdP-Links haben (z.B. GitHub + Google)?
- Wie kann man den First Login Flow anpassen? (z.B. automatisch erstellen ohne Review)

---

## Aufräumen

1. Den über GitHub erstellten User löschen (**Users** → User auswählen → **Delete**)
2. Identity Provider entfernen (**Identity providers** → **github** → **Delete**)
3. Optional: GitHub OAuth App löschen (GitHub → Settings → Developer settings → OAuth Apps)
