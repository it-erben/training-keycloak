# OAuth 2.0: Device Authorization Flow

## Deine Aufgabe

Stelle den anderen Teilnehmenden den **Device Authorization Flow**
(auch "Device Flow") vor (~10 Minuten). Nutze dieses Material als Grundlage. Du
kannst es ergänzen oder anpassen.

---

## 1. Was ist der Device Flow?

Der Device Flow (RFC 8628) ist ein OAuth 2.0 Grant Type für Geräte, die **keinen
komfortablen Browser oder keine Tastatur** haben.

**Kernidee:** Der Benutzer autorisiert auf einem **zweiten Gerät**
(z.B. Smartphone oder Laptop), während das eigentliche Gerät wartet.

### Wann wird er eingesetzt?

- Smart-TVs (Netflix, YouTube, Disney+)
- Spielekonsolen (Xbox, PlayStation)
- IoT-Geräte mit kleinem oder keinem Display
- CLI-Tools (z.B. `gh auth login` bei GitHub, `az login` bei Azure)
- Drucker oder Set-Top-Boxen

### Das Problem, das er löst

Stell dir vor, du sollst dich auf einem Smart-TV bei einem Streaming-Dienst
einloggen. Die Eingabe von E-Mail und Passwort mit einer Fernbedienung ist
extrem umständlich. Der Device Flow löst dieses Problem elegant.

---

## 2. Ablauf des Flows

```
┌──────────┐                               ┌──────────────────────┐
│          │  1. Device Authorization      │                      │
│  Device  │     Request                   │  Authorization       │
│  (TV)    │ ─────────────────────────────>│  Server (Keycloak)   │
│          │                               │                      │
│          │  2. device_code +             │                      │
│          │     user_code + URL           │                      │
│          │ <─────────────────────────────│                      │
│          │                               │                      │
│          │    ┌─────────────────┐        │                      │
│  Zeigt:  │    │  User öffnet    │  3.    │                      │
│  "Gehe   │    │  URL auf Handy  │───────>│                      │
│  zu URL, │    │  und gibt Code  │        │                      │
│  Code:   │    │  ein            │        │                      │
│  ABCD"   │    └─────────────────┘        │                      │
│          │                               │                      │
│          │  4. Polling: "Schon fertig?"  │                      │
│          │ ─────────────────────────────>│                      │
│          │                               │                      │
│          │  5. Access Token              │                      │
│          │ <─────────────────────────────│                      │
└──────────┘                               └──────────────────────┘
```

### Schritt für Schritt

1. **Device Authorization Request:** Das Gerät fragt beim Authorization Server
   einen Device Code und User Code an.
2. **Antwort:** Der Server gibt einen `device_code`, einen `user_code`
   und eine `verification_uri` zurück.
3. **Benutzeraktion:** Das Gerät zeigt dem Benutzer die URL und den Code an. Der
   Benutzer öffnet die URL auf einem anderen Gerät (Handy/Laptop), gibt den Code
   ein und loggt sich dort ein.
4. **Polling:** Während der Benutzer sich anmeldet, fragt das Gerät in
   regelmäßigen Abständen beim Token-Endpoint nach, ob die Autorisierung
   abgeschlossen ist.
5. **Token:** Sobald der Benutzer den Code bestätigt hat, erhält das Gerät ein
   Access Token.

---

## 3. Beispiel-HTTP-Requests

### Schritt 1: Device Authorization Request

```http
POST /realms/mustertech/protocol/openid-connect/auth/device HTTP/1.1
Host: keycloak.example.com
Content-Type: application/x-www-form-urlencoded

client_id=smart-tv-app
&scope=openid profile
```

### Schritt 2: Device Authorization Response

```json
{
  "device_code": "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
  "user_code": "ABCD-EFGH",
  "verification_uri": "https://keycloak.example.com/realms/mustertech/device",
  "verification_uri_complete": "https://keycloak.example.com/realms/mustertech/device?user_code=ABCD-EFGH",
  "expires_in": 600,
  "interval": 5
}
```

> **Das Gerät zeigt jetzt an:**
> "Gehe zu `https://keycloak.example.com/.../device` und gib den Code
> **ABCD-EFGH** ein."

### Schritt 4: Polling (Token Request)

```http
POST /realms/mustertech/protocol/openid-connect/token HTTP/1.1
Host: keycloak.example.com
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:device_code
&device_code=GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS
&client_id=smart-tv-app
```

### Polling-Antworten

**Wenn der Benutzer noch nicht fertig ist:**

```json
{
  "error": "authorization_pending"
}
```

**Wenn das Gerät zu schnell pollt:**

```json
{
  "error": "slow_down"
}
```

**Wenn der Benutzer autorisiert hat:**

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 300,
  "refresh_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

## 4. Vergleich mit dem Authorization Code Flow

| Aspekt                           | Authorization Code Flow | Device Flow                   |
|:---------------------------------|:------------------------|:------------------------------|
| **Browser auf dem Gerät nötig?** | Ja                      | Nein                          |
| **Tastatureingabe nötig?**       | Ja (auf dem Gerät)      | Nein (auf dem Gerät)          |
| **Zweites Gerät nötig?**         | Nein                    | Ja                            |
| **Benutzer beteiligt?**          | Ja                      | Ja                            |
| **Redirect-basiert?**            | Ja                      | Nein (Polling statt Redirect) |
| **Typischer Client**             | Web-App, Mobile App     | Smart-TV, IoT, CLI            |

---

## 5. Sicherheitsaspekte

- Der **User Code muss kurz und lesbar** sein (z.B. `ABCD-EFGH`), damit der
  Benutzer ihn einfach abtippen kann.
- Der **Device Code ist geheim** und darf nicht angezeigt werden.
- Das **Polling-Interval** muss eingehalten werden (`interval`-Feld), um den
  Server nicht zu überlasten. Wird zu oft gepollt, antwortet der Server mit
  `slow_down`.
- Der Code hat eine **begrenzte Gültigkeit** (`expires_in`), nach der der Flow
  neu gestartet werden muss.
- **Phishing-Risiko:** Ein Angreifer könnte einen falschen Code auf einem
  fremden Gerät anzeigen. Deshalb sollte der Consent-Screen deutlich machen,
  welches Gerät autorisiert wird.

---

## 6. Alltagsbeispiele

Hast du schon einmal einen dieser Flows benutzt?

- **YouTube auf dem Smart-TV:** "Gehe zu youtube.com/activate und gib diesen
  Code ein"
- **GitHub CLI:** `gh auth login` zeigt einen Code an und öffnet die
  GitHub-Seite im Browser
- **Azure CLI:** `az login` nutzt denselben Mechanismus
- **Spotify auf Spielekonsolen:** Code-Eingabe über smartphone

---

## 7. Diskussionsfragen für die Gruppe

- Wo seid ihr dem Device Flow im Alltag schon begegnet?
- Warum nutzt der Device Flow Polling und nicht z.B. WebSockets?
- Was passiert, wenn der Benutzer den Code nie eingibt? Wie verhält sich das
  Gerät?
- Welche Risiken seht ihr beim Device Flow, die es beim Authorization Code Flow
  nicht gibt?

---

## Hinweise zu den Diskussionsfragen

### "Wo seid ihr dem Device Flow im Alltag schon begegnet?"

Typische Antworten:

- **Streaming-Dienste auf Smart-TVs:** YouTube ("youtube.com/activate"),
  Netflix, Disney+, Amazon Prime Video
- **Spielekonsolen:** Xbox, PlayStation, Nintendo Switch bei der Anmeldung
  an Online-Diensten
- **CLI-Tools für Entwickler:** `gh auth login` (GitHub), `az login`
  (Azure), `gcloud auth login` (Google Cloud), `aws sso login` (AWS)
- **Smart-Home-Geräte:** Alexa-Skill-Verknüpfungen, Google-Home-Setup
- **Drucker/Scanner:** Cloud-Print-Dienste, die eine Anmeldung erfordern

### "Warum Polling und nicht WebSockets?"

- **Einfachheit:** Das Gerät (z.B. ein Smart-TV oder ein eingebettetes
  System) hat möglicherweise **keine WebSocket-Bibliothek** oder nur
  einen minimalen HTTP-Client.
- **Firewall-Kompatibilität:** Einfache HTTP-POST-Requests funktionieren
  überall. WebSockets erfordern ein Upgrade des Protokolls, was von
  Firewalls oder Proxies blockiert werden kann.
- **Zustandslosigkeit des Servers:** Der Authorization Server muss keine
  offene Verbindung pro Gerät halten. Bei Millionen von Geräten (z.B.
  YouTube auf Smart-TVs weltweit) wäre das ein enormer Ressourcenaufwand.
- **Robustheit:** Wenn die Verbindung kurz unterbrochen wird (WLAN-Wechsel
  etc.), ist Polling automatisch resilient, der nächste Request geht
  einfach durch. Bei WebSockets müsste die Verbindung neu aufgebaut werden.

### "Was passiert, wenn der Code nie eingegeben wird?"

- Das Gerät pollt so lange, bis der Code **abläuft** (`expires_in`,
  typisch 5-15 Minuten).
- Nach Ablauf antwortet der Server mit `"error": "expired_token"`.
- Das Gerät zeigt dem Benutzer dann eine Meldung an (z.B. "Zeitlimit
  überschritten") und bietet an, den Flow **neu zu starten**, also
  einen neuen Device Code und User Code anzufordern.
- Während der Polling-Phase verbraucht das Gerät nur minimale Ressourcen,
  da zwischen den Requests jeweils das `interval` (z.B. 5 Sekunden)
  gewartet wird.

### "Welche Risiken gibt es, die der Authorization Code Flow nicht hat?"

- **Remote Phishing:** Ein Angreifer startet den Device Flow auf seinem
  eigenen Gerät und bringt ein Opfer dazu, den Code auf einer legitimen
  Login-Seite einzugeben (z.B. per Social Engineering: "Gib bitte diesen
  Code ein, um dein Konto zu verifizieren"). Das Opfer autorisiert
  unwissentlich das Gerät des Angreifers. Beim Authorization Code Flow
  ist das schwieriger, weil der Redirect direkt an die richtige App geht.
- **Keine Gerätebindung:** Der User Code kann von **jedem** eingegeben
  werden, es gibt keine kryptographische Bindung zwischen dem Gerät
  und dem Benutzer wie z.B. bei PKCE im Authorization Code Flow.
- **Polling als Angriffsfläche:** Ein Angreifer könnte versuchen, den
  Device Code zu erraten und parallel zu pollen. Deshalb müssen Device
  Codes ausreichend lang und zufällig sein.
- **Gegenmaßnahmen:** Consent-Screen sollte klar anzeigen, welches Gerät
  und welche Berechtigungen autorisiert werden. Kurze Code-Gültigkeit
  begrenzt das Zeitfenster für Angriffe.
