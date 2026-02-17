# Live-Demo: Modul 06 -- SSO, Sessions & Tokens

Session-Timeouts und Revocation live zeigen -- kurze, eindrückliche Demos, die das Thema greifbar machen.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Session-Timeout testen | 4 Min |
| Demo 2 | Revocation testen | 3 Min |

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

Der Realm **mustertech** wird automatisch importiert (mit User `alice` / `demo1234`).

---

## Demo 1: Session-Timeout testen

Wir setzen die maximale Session-Dauer auf 2 Minuten und beobachten, wie der User automatisch ausgeloggt wird.

### Schritt 1 -- SSO Session Max reduzieren

1. Navigiere zu **Realm settings** -> **Sessions**
2. Ändere:

| Einstellung | Alter Wert | Neuer Wert |
| :--- | :--- | :--- |
| SSO Session Max | 10 Stunden | **2 Minuten** |

3. Klicke auf **Save**

### Schritt 2 -- Login in Account Console

1. Öffne ein **Inkognito-Fenster**
2. Navigiere zu: <http://localhost:9090/realms/mustertech/account>
3. Melde dich mit `alice` / `demo1234` an
4. **Notiere die Uhrzeit**

### Schritt 3 -- Warten und prüfen

1. Warte **2-3 Minuten**
2. Klicke in der Account Console auf einen Link (z.B. **Personal info**)
3. Keycloak leitet dich zur Login-Seite zurück

> **Zeigen:** Die SSO Session ist abgelaufen. Egal wie aktiv der User war -- nach SSO
> Session Max ist Schluss. Das ist der Unterschied zu SSO Session Idle
> (Inaktivitäts-Timeout).

**Diskussionspunkte:**

- Was ist ein sinnvoller Wert für SSO Session Max? (8h für Büro, 30 Min für Banking)
- Was ist der Unterschied zu Access Token Lifespan?
- Wie reagieren SPAs auf abgelaufene Sessions?

---

## Demo 2: Revocation testen

Der "Notfall-Knopf": Alle Tokens sofort ungültig machen.

### Schritt 1 -- Einloggen

1. Öffne ein **Inkognito-Fenster**
2. Melde dich in der Account Console an: <http://localhost:9090/realms/mustertech/account>
3. Prüfe: Login ist erfolgreich, Account Console wird angezeigt

### Schritt 2 -- Revocation setzen

1. Wechsle zur **Admin-Konsole**
2. Navigiere zu **Sessions** (linke Navigation)
3. Klicke auf den Tab **Revocation**
4. Klicke auf **Set to now**
5. Klicke auf **Push**

### Schritt 3 -- Auswirkung prüfen

1. Wechsle zurück zum Inkognito-Fenster
2. Klicke auf einen Link in der Account Console (z.B. **Personal info**)
3. Keycloak leitet dich zur Login-Seite zurück -- die Session wurde ungültig

> **Zeigen:** Alle Tokens, die **vor** dem Revocation-Zeitpunkt ausgestellt wurden, sind
> sofort ungültig. Das ist der Notfall-Mechanismus bei einem Sicherheitsvorfall.

**Diskussionspunkte:**

- Wann braucht man Revocation? (Kompromittierte Tokens, Sicherheitsvorfall)
- Was ist der Unterschied zu "Sign out all active sessions"?
- Wie schnell wirkt Revocation? (Beim nächsten Token-Refresh)

---

## Aufräumen

```bash
docker compose down -v
```
