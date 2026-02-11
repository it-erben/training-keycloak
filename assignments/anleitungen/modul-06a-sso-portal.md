# Modul 06a: SSO konfigurieren - React Portal

## Übungsziel

Am Ende dieser Übung hast du:

- Einen OIDC-Client in Keycloak konfiguriert
- Eine App integrieren mit Keycloak
- User-Informationen aus dem Token angezeigt

**Geschätzte Dauer:** 30-35 Minuten

---

## Voraussetzungen

- [ ] Modul 05 abgeschlossen (Custom Auth Flow)

---

## Teil 1: OIDC-Client in Keycloak anlegen

### Schritt 1.1: Neuen Client erstellen

1. Öffne die Admin-Konsole: <http://localhost:8080>
2. Wähle den Realm **mustertech**
3. Navigiere zu **Clients**
4. Klicke auf **Create client**

### Schritt 1.2: Client-Typ konfigurieren

**General settings:**

| Feld | Wert |
| :--- | :--- |
| **Client type** | OpenID Connect |
| **Client ID** | `portal-frontend` |
| **Name** | `Mustertech Portal` |
| **Description** | `React Single Page Application für Mitarbeiter` |

Klicke auf **Next**.

### Schritt 1.3: Capability config

| Feld | Wert |
| :--- | :--- |
| **Client authentication** | OFF (Public Client für SPA) |
| **Authorization** | OFF |
| **Authentication flow** | ☑ Standard flow, ☑ Direct access grants |

Klicke auf **Next**.

### Schritt 1.4: Login settings

| Feld | Wert |
| :--- | :--- |
| **Root URL** | `http://localhost:5173` |
| **Home URL** | `http://localhost:5173` |
| **Valid redirect URIs** | `http://localhost:5173/*` |
| **Valid post logout redirect URIs** | `http://localhost:5173/*` |
| **Web origins** | `http://localhost:5173` |

Klicke auf **Save**.

### Schritt 1.5: Client verifizieren

Nach dem Speichern:

1. Gehe zum Tab **Settings**
2. Verifiziere die Einstellungen
3. Notiere dir die **Client ID**: `portal-frontend`

---

## Teil 2: Code-Walkthrough - Die Portal-Anwendung verstehen

Die Portal-Anwendung liegt fertig im Verzeichnis `services/portal-frontend/`. Bevor wir sie mit
Keycloak verbinden, schauen wir uns den Code an, um zu verstehen, wie die Anwendung aufgebaut
ist und wie die OIDC-Integration funktioniert.

### Technologie-Überblick

Die Anwendung nutzt folgende Technologien:

| Technologie | Zweck |
| :--- | :--- |
| **React** | UI-Bibliothek - baut die Benutzeroberfläche aus wiederverwendbaren Komponenten auf |
| **TypeScript** | Typisiertes JavaScript - hilft Fehler bereits beim Entwickeln zu erkennen |
| **Vite** | Build-Tool & Entwicklungsserver - startet schnell und bündelt den Code für Produktion |
| **oidc-client-ts** | OIDC-Bibliothek - implementiert den Authorization Code Flow im Browser |
| **react-oidc-context** | React-Wrapper um `oidc-client-ts` - stellt Login-Status als React-Hook bereit |

### Schritt 2.1: Projektstruktur

```text
services/portal-frontend/
├── index.html              ← HTML-Einstiegspunkt (lädt main.tsx)
├── package.json            ← Abhängigkeiten und Scripts
├── vite.config.ts          ← Vite-Konfiguration
├── Dockerfile              ← Container-Build (mehrstufig)
├── nginx.conf              ← Webserver-Konfiguration für Produktion
├── .env                    ← Umgebungsvariablen (Keycloak-URL etc.)
└── src/
    ├── main.tsx            ← React-Einstiegspunkt
    ├── App.tsx             ← Haupt-Komponente (Login, Profil, Token-Anzeige)
    ├── auth/
    │   └── oidc-config.ts  ← OIDC-Konfiguration für Keycloak
    ├── App.css             ← Styling der App-Komponente
    └── index.css           ← Globale CSS-Grundeinstellungen
```

### Schritt 2.2: Einstiegspunkt - `index.html` und `main.tsx`

Jede Webanwendung beginnt mit einer HTML-Datei. Unsere `index.html` ist minimal:

```html
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.tsx"></script>
</body>
```

Das `<div id="root">` ist der Container, in den React die gesamte Benutzeroberfläche rendert.
Das `<script>`-Tag lädt unseren TypeScript-Code. Vite kompiliert dabei TypeScript automatisch
zu JavaScript.

Die Datei `src/main.tsx` verbindet React mit diesem HTML-Element:

```tsx
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AuthProvider {...oidcConfig}>
      <App />
    </AuthProvider>
  </React.StrictMode>
);
```

Hier passiert Folgendes:

- `ReactDOM.createRoot(...)` erzeugt die React-Anwendung im `root`-Element
- `<AuthProvider>` umschließt die gesamte App und stellt die OIDC-Authentifizierung bereit.
  Jede Komponente innerhalb des Providers kann auf den Login-Status zugreifen.
- `<App />` ist unsere Haupt-Komponente, die die eigentliche Benutzeroberfläche enthält

> **Konzept: Provider-Pattern** - In React umschließt ein *Provider* andere Komponenten und
> stellt ihnen gemeinsame Daten zur Verfügung (hier: den Authentifizierungsstatus). Alle
> Kind-Komponenten innerhalb des Providers können diese Daten nutzen, ohne sie einzeln
> weitergeben zu müssen.

### Schritt 2.3: OIDC-Konfiguration - `src/auth/oidc-config.ts`

Diese Datei konfiguriert die Verbindung zu Keycloak:

```typescript
export const oidcConfig: UserManagerSettings = {
  authority: `${keycloakUrl}/realms/${realm}`,
  client_id: clientId,
  redirect_uri: window.location.origin + '/',
  post_logout_redirect_uri: window.location.origin + '/',
  response_type: 'code',
  scope: 'openid profile email',
  automaticSilentRenew: true,
  userStore: new WebStorageStateStore({ store: window.localStorage }),
};
```

| Eigenschaft | Bedeutung |
| :--- | :--- |
| `authority` | URL des Keycloak-Realms - die Bibliothek lädt automatisch die OIDC-Discovery-Konfiguration von `{authority}/.well-known/openid-configuration` |
| `client_id` | Die Client-ID, die wir in Teil 1 in Keycloak angelegt haben |
| `redirect_uri` | Wohin Keycloak nach dem Login zurückleiten soll |
| `post_logout_redirect_uri` | Wohin Keycloak nach dem Logout zurückleiten soll |
| `response_type` | `code` = Authorization Code Flow (empfohlen für SPAs) |
| `scope` | Welche Informationen wir anfordern: OpenID-Standard, Profilname, E-Mail |
| `automaticSilentRenew` | Tokens werden automatisch im Hintergrund erneuert, bevor sie ablaufen |
| `userStore` | Speichert die Session im `localStorage` des Browsers (überlebt Seiten-Neuladen) |

Die Werte für `keycloakUrl`, `realm` und `clientId` kommen aus Umgebungsvariablen
(`import.meta.env.VITE_*`). Das Präfix `VITE_` ist eine Vite-Konvention: nur Variablen
mit diesem Präfix sind im Browser-Code verfügbar.

### Schritt 2.4: Haupt-Komponente - `src/App.tsx`

Die `App`-Komponente ist das Herzstück der Anwendung. Sie nutzt den `useAuth()`-Hook, um auf
den Authentifizierungsstatus zuzugreifen:

```tsx
function App() {
  const auth = useAuth();
  // ...
}
```

> **Konzept: React Hooks** - Ein Hook ist eine Funktion, die einer Komponente Zugriff auf
> externe Daten gibt. `useAuth()` liefert den aktuellen Login-Status und Funktionen wie
> `signinRedirect()` oder `signoutRedirect()`.

Die Komponente behandelt vier Zustände:

**1. Ladevorgang** (`auth.isLoading`):
Während die Bibliothek prüft, ob eine gültige Session existiert, wird "Lädt..." angezeigt.

**2. Fehler** (`auth.error`):
Wenn die Verbindung zu Keycloak fehlschlägt, wird eine Fehlermeldung mit Retry-Button
angezeigt.

**3. Eingeloggt** (`auth.isAuthenticated`):
Nach erfolgreichem Login zeigt die Anwendung:

- **Header** mit Begrüßung und Abmelde-Button
- **Profil-Karte** mit Name, E-Mail und Username aus dem Token (`auth.user.profile`)
- **Token-Informationen** - Access Token und ID Token Claims als aufklappbare Bereiche

```tsx
// Beispiel: Zugriff auf Benutzerdaten aus dem Token
auth.user.profile.name                // Voller Name
auth.user.profile.email               // E-Mail-Adresse
auth.user.profile.preferred_username   // Username
auth.user.access_token                 // Das Access Token (JWT-String)
```

**4. Nicht eingeloggt** (Standard):
Zeigt eine Willkommensmeldung und einen Login-Button, der `auth.signinRedirect()` aufruft.
Diese Methode leitet den Browser zu Keycloak weiter - dort meldet sich der Nutzer an und wird
anschließend mit einem Authorization Code zurück zur App geleitet.

### Schritt 2.5: Deployment - `Dockerfile` und `nginx.conf`

Die Anwendung wird in einem zweistufigen Docker-Build gebaut:

**Stufe 1 - Build:**

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci           # Abhängigkeiten installieren
COPY . .
RUN npm run build    # TypeScript kompilieren + Vite-Bundle erzeugen
```

`npm run build` erzeugt im Ordner `dist/` eine optimierte Version der App: minimiertes
JavaScript, CSS und die `index.html`. Diese statischen Dateien sind alles, was im Browser
benötigt wird.

**Stufe 2 - Ausliefern:**

```dockerfile
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

Ein schlanker Nginx-Webserver liefert die statischen Dateien aus. Die `nginx.conf` enthält
eine wichtige Regel für Single Page Applications:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

Diese Regel bewirkt: Wenn eine angefragte Datei nicht existiert, wird stattdessen
`index.html` ausgeliefert. Das ist nötig, weil bei einer SPA das Routing im Browser
(in JavaScript) stattfindet, nicht auf dem Server.

---

## Teil 3: OIDC-Konfiguration

### Schritt 3.1: Umgebungsvariablen prüfen

Prüfe die `services/portal-frontend/.env`:

```env
VITE_KEYCLOAK_URL=http://localhost:8080
VITE_KEYCLOAK_REALM=mustertech
VITE_KEYCLOAK_CLIENT_ID=portal-frontend
```

Hiermit teilen wir der Anwendung mit, unter welcher URL, mit welchem Realm und welcher Client ID
Keycloak zu erreichen ist.

### Schritt 3.2: docker-compose.yml erweitern

Füge in der Haupt-`docker-compose.yml` folgenden Eintrag hinzu, um das Portal-Projekt einzubinden:

```yaml
  # Nach dem keycloak-Service:

  portal-frontend:
    build:
      context: ./services/portal-frontend
      dockerfile: Dockerfile
    container_name: mustertech-portal
    ports:
      - "5173:80"
    depends_on:
      keycloak:
        condition: service_healthy
    networks:
      - mustertech-network
```

---

## Teil 4: Personalnummer im ID Token anzeigen

In Modul 04 haben wir jedem Benutzer ein Attribut `personalnummer` vergeben. Standardmäßig
erscheinen benutzerdefinierte Attribute **nicht** im Token. Damit die Portal-Anwendung die
Personalnummer anzeigen kann, müssen wir einen **Protocol Mapper** konfigurieren, der das
Attribut ins ID Token aufnimmt.

> **Warum ID Token?** Das ID Token enthält Identitätsinformationen (*Wer bist du?*). Die
> Personalnummer identifiziert den Mitarbeiter und gehört daher ins ID Token. Das Access Token
> hingegen enthält Berechtigungsinformationen (*Was darfst du?*) wie Rollen und Scopes.

### Schritt 4.1: Protocol Mapper anlegen

1. Navigiere zu **Clients** → **portal-frontend**
2. Wechsle zum Tab **Client scopes**
3. Klicke auf **portal-frontend-dedicated**
4. Klicke auf **Configure a new mapper**
5. Wähle **User Attribute**

Konfiguriere den Mapper:

| Feld | Wert |
| :--- | :--- |
| **Name** | `personalnummer` |
| **User Attribute** | `personalnummer` |
| **Token Claim Name** | `personalnummer` |
| **Claim JSON Type** | String |
| **Add to ID token** | ON |
| **Add to access token** | OFF |
| **Add to userinfo** | ON |
| **Add to token introspection** | ON |

Klicke auf **Save**.

### Schritt 4.2: App anpassen

Öffne `services/portal-frontend/src/App.tsx` und ergänze in der Profil-Tabelle eine Zeile
für die Personalnummer:

```tsx
<tr>
  <td><strong>Personalnummer:</strong></td>
  <td>{String(auth.user.profile['personalnummer'] ?? '–')}</td>
</tr>
```

Der Zugriff erfolgt über `auth.user.profile['personalnummer']`, da es sich um einen
benutzerdefinierten Claim handelt, der nicht zum Standard-OIDC-Profil gehört. Daher nutzen
wir die Bracket-Notation statt `auth.user.profile.personalnummer`.

### Schritt 4.3: Ergebnis prüfen

Nach dem Neustart (`docker compose up --build`) und erneutem Login solltest du:

1. Die **Personalnummer** im Profil-Bereich sehen (z.B. `M-1001` für Hans Müller)
2. Im aufklappbaren **ID Token Claims**-Bereich den Claim `"personalnummer": "M-1001"` finden
3. Im **Access Token** (via [jwt.io](https://jwt.io) decodiert) die Personalnummer
   **nicht** sehen - sie ist bewusst nur im ID Token

---

## Schritt 5: Test

Navigiere mit deinem Browser auf [http://localhost:5173/](http://localhost:5173/) und melde dich an:

- Username: `hans.mueller`
- Password: `test1234`

Betrachte danach Access- und ID-Token.

---

## Zusammenfassung

Du hast erfolgreich:

- [x] OIDC-Client in Keycloak konfiguriert (Public Client)
- [x] Den Aufbau der React-Anwendung und die OIDC-Integration verstanden
- [x] Docker-Integration vorbereitet
- [x] Einen Protocol Mapper für die Personalnummer im ID Token konfiguriert
- [x] User-Informationen aus dem Token angezeigt
