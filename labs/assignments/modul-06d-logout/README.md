# Modul 06d: Front- und Backchannel-Logout

## Übungsziel

- Verstehen, warum Single Sign-On auch ein **Single-Logout-Problem** hat
- **Frontchannel-Logout** konfigurieren und testen
- **Backchannel-Logout** konfigurieren und testen
- Unterschiede zwischen beiden Verfahren kennen und bewerten

## Aufbau der Übung

Zwei Express-Anwendungen (**App A** auf Port 3001, **App B** auf Port 3002)
sind als OIDC-Clients bei Keycloak registriert. Beide nutzen serverseitige
Sessions und implementieren Login über den Authorization Code Flow.

Die Clients sind vorkonfiguriert – Login und SSO funktionieren sofort.
**Logout-Benachrichtigungen sind jedoch bewusst nicht konfiguriert.**
Das ist eure Aufgabe.

| Service       | URL                           | Beschreibung                       |
| :------------ | :---------------------------- | :--------------------------------- |
| App A         | <http://localhost:3001>       | Demo-App (Express, Client `app-a`) |
| App B         | <http://localhost:3002>       | Demo-App (Express, Client `app-b`) |
| Keycloak      | <http://localhost:8080>       | Identity Provider                  |
| Admin Console | <http://localhost:8080/admin> | Admin: `admin` / `admin`           |

## Umgebung starten

```bash
cd assignments/modul-06d-logout
docker compose up -d --build
```

> **Hinweis:** Falls Container aus einer anderen Übung laufen,
> diese vorher stoppen:
> `docker compose -f ../modul-XX-.../docker-compose.yml down`

Warte, bis alle Container gestartet sind. Keycloak braucht ca. 30–60 Sekunden.
Prüfe mit:

```bash
docker compose ps
```

Alle Services sollten `running (healthy)` oder `exited (0)` (Setup-Container)
anzeigen.

Öffne ein **separates Terminal** für die App-Logs – diese wirst du im Verlauf
der Übung beobachten:

```bash
docker compose logs -f assignment-app-a assignment-app-b
```

---

## Teil 1: SSO und das Logout-Problem

### Schritt 1.1: Apps öffnen

Öffne beide Apps im Browser:

- **App A:** <http://localhost:3001>
- **App B:** <http://localhost:3002>

Beide zeigen "Nicht eingeloggt".

### Schritt 1.2: Login und SSO testen

1. Klicke in **App A** auf **"Login mit Keycloak"**
2. Melde dich an mit: `hans.mueller` / `test1234`
3. App A zeigt: "Eingeloggt als Hans Müller"
4. Wechsle zu **App B** und klicke auf **"Login mit Keycloak"**
5. **Keine erneute Anmeldung nötig!** App B ist sofort eingeloggt (SSO)

### Schritt 1.3: Logout ohne Front- und Backchannel testen

1. Klicke in **App A** auf **"Logout"**
2. App A zeigt wieder "Nicht eingeloggt"
3. **Lade App B im Browser neu** (F5)
4. App B zeigt **immer noch "Eingeloggt"**

### Schritt 1.4: Sessions in der Admin Console prüfen

1. Öffne die **Keycloak Admin Console**: <http://localhost:8080/admin>
2. Melde dich an: `admin` / `admin`
3. Wähle den Realm **"mustertech"** (Dropdown oben links)
4. Navigiere zu **Sessions** im linken Menü
5. Die Keycloak-Session von `hans.mueller` ist **beendet** –
   aber App B weiß davon nichts

> **Warum passiert das?** Beim Logout beendet Keycloak seine eigene Session.
> Aber die lokalen Sessions der einzelnen Anwendungen bleiben bestehen,
> solange Keycloak diese nicht aktiv benachrichtigt.
> Genau dafür gibt es Front- und Backchannel-Logout.

---

## Teil 2: Frontchannel-Logout konfigurieren

Beim Frontchannel-Logout bettet Keycloak auf seiner Logout-Seite
**versteckte iframes** ein, die die Logout-URLs der Clients aufrufen.
Der **Browser des Users** macht diese Requests.

```text
User klickt Logout
        │
        ▼
┌─────────────────────┐
│  Keycloak Logout-   │
│  Seite (Browser)    │
│                     │
│  ┌───────────────┐  │
│  │ <iframe>      │  │──→ GET /frontchannel-logout?sid=...
│  │ App A Logout  │  │        (http://localhost:3001)
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ <iframe>      │  │──→ GET /frontchannel-logout?sid=...
│  │ App B Logout  │  │        (http://localhost:3002)
│  └───────────────┘  │
└─────────────────────┘
```

### Schritt 2.1: Client-Einstellungen anpassen

1. Öffne in der Admin Console: **Clients** → **app-a**
2. Scrolle zum Abschnitt **"Logout settings"**
3. Aktiviere **"Front channel logout"** (Schalter auf ON)
4. Trage als **"Front-Channel Logout URL"** ein:

   ```text
   http://localhost:3001/frontchannel-logout
   ```

5. Klicke **"Save"**

Wiederhole die Schritte für **app-b** mit der URL:

```text
http://localhost:3002/frontchannel-logout
```

### Schritt 2.2: Testen

1. Stelle sicher, dass die **Logs** im separaten Terminal laufen
2. Öffne **App A** (<http://localhost:3001>)
   → Login mit `hans.mueller` / `test1234`
3. Öffne **App B** (<http://localhost:3002>)
   → Login (SSO, keine Anmeldung nötig)
4. Klicke in **App A** auf **"Logout"**
5. **Lade App B neu** (F5) → "Nicht eingeloggt"

**Beobachte die Logs:**

```text
[App A] [LOGOUT]              Hans Müller hat Logout ausgelöst
...
[App B] [FRONTCHANNEL-LOGOUT] Empfangen – sid=..., iss=...
[App B] [FRONTCHANNEL-LOGOUT] Session zerstört für sid=...
```

> **Was passiert im Detail?**
>
> 1. App A zerstört die eigene Session und leitet zu Keycloaks
>    `end_session_endpoint` weiter
> 2. Keycloak beendet die SSO-Session
> 3. Keycloak rendert eine Logout-Seite mit versteckten iframes
>    für jeden registrierten Client
> 4. Der Browser lädt die iframes → GET-Requests an die
>    Frontchannel-Logout-URLs
> 5. Die Apps empfangen die Requests mit `sid` (Session-ID)
>    als Query-Parameter
> 6. Die Apps finden und zerstören die passende lokale Session

Frontchannel-Logout hat einige Schwächen:

- **Browser muss offen sein:** Wenn der User den Tab schließt,
  werden die iframes nicht geladen
- **Third-Party-Cookie-Problem:** Moderne Browser blockieren Cookies
  in iframes von anderen Origins – die Session-Zuordnung muss über
  den `sid`-Parameter statt über Cookies erfolgen
- **Unzuverlässig:** Popup-Blocker, Netzwerkprobleme oder langsame
  Apps können den Logout verhindern
- **Sichtbar für den User:** Die Keycloak-Logout-Seite muss warten,
  bis alle iframes geladen sind

---

## Teil 3: Backchannel-Logout konfigurieren

Beim Backchannel-Logout sendet **Keycloak direkt HTTP-POST-Requests**
an die Anwendungen – ohne Umweg über den Browser.
Der Request enthält ein **Logout-Token** (JWT).

```text
User klickt Logout
        │
        ▼
┌──────────────┐
│   Keycloak   │──POST──→ /backchannel-logout
│   (Server)   │          (http://assignment-app-a:3001)
│              │          Body: logout_token=eyJ...
│              │
│              │──POST──→ /backchannel-logout
│              │          (http://assignment-app-b:3002)
│              │          Body: logout_token=eyJ...
└──────────────┘
```

### Schritt 3.1: Frontchannel-Logout deaktivieren

1. Öffne **Clients** → **app-a** → **"Logout settings"**
2. Deaktiviere **"Front channel logout"** (Schalter auf OFF)
3. Trage als **"Backchannel logout URL"** ein:

   ```text
   http://assignment-app-a:3001/backchannel-logout
   ```

4. Aktiviere **"Backchannel logout session required"**
5. Klicke **"Save"**

Wiederhole für **app-b**:

- Backchannel logout URL:

  ```text
  http://assignment-app-b:3002/backchannel-logout
  ```

- "Backchannel logout session required": **aktiviert**

> **Wichtig:** Die Backchannel-URLs verwenden die
> **Docker-internen Hostnamen** (`assignment-app-a` statt `localhost`),
> weil Keycloak die Requests direkt von Server zu Server sendet –
> nicht über den Browser des Users!

### Schritt 3.2: Testen

1. Öffne **App A** → Login mit `hans.mueller` / `test1234`
2. Öffne **App B** → Login (SSO)
3. Klicke in **App A** auf **"Logout"**
4. **Lade App B neu** (F5) → "Nicht eingeloggt" ✓

**Beobachte die Logs:**

```text
[App A] [LOGOUT]               Hans Müller hat Logout ausgelöst
[App B] [BACKCHANNEL-LOGOUT]   Empfangen – sid=..., sub=..., events=...
[App B] [BACKCHANNEL-LOGOUT]   Session zerstört für sid=...
...
```

> **Was passiert im Detail?**
>
> 1. App A zerstört die eigene Session und leitet zu Keycloaks
>    `end_session_endpoint` weiter
> 2. Keycloak beendet die SSO-Session
> 3. Keycloak sendet POST-Requests an die Backchannel-Logout-URLs
>    aller Clients
> 4. Der Request-Body enthält ein `logout_token` (JWT) mit `sid`
>    (Session-ID) und `sub` (User-ID)
> 5. Die Apps dekodieren das Token, finden die passende Session
>    und zerstören sie
> 6. Die Apps antworten mit `200 OK`

Die Option **"Backchannel logout session required"** steuert,
ob das Logout-Token einen `sid`-Claim enthält:

- **Aktiviert:** Das Token enthält `sid` → die App kann gezielt
  die richtige Session zerstören
- **Deaktiviert:** Das Token enthält nur `sub` → die App muss
  **alle** Sessions dieses Users zerstören

Für unsere Übung ist die Option aktiviert, weil wir Sessions gezielt
über die Session-ID zuordnen.

---

## Zusammenfassung

- [ ] SSO-Login über zwei Apps getestet
- [ ] Logout-Problem ohne Benachrichtigung erlebt und verstanden
- [ ] Frontchannel-Logout konfiguriert und in den Logs beobachtet
- [ ] Backchannel-Logout konfiguriert und in den Logs beobachtet
- [ ] Unterschiede zwischen Front- und Backchannel-Logout verstanden
- [ ] Die Rolle von Docker-Netzwerk-URLs bei Backchannel-Logout verstanden
- [ ] Sessions in der Keycloak Admin Console geprüft
