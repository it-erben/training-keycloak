# Live-Demo: Modul 05 -- Authentifizierung & MFA

Den Browser-Flow duplizieren und OTP für **alle User** erzwingen (Required statt
Conditional) -- im Gegensatz zur Übung, die Conditional OTP nach Rolle konfiguriert.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Flow duplizieren | 2 Min |
| Demo 2 | OTP auf Required setzen | 3 Min |
| Demo 3 | Flow binden | 1 Min |
| Demo 4 | Login testen | 3 Min |

## Voraussetzungen

- Docker / Podman (Container-Runtime)
- Smartphone mit Authenticator-App (Google Authenticator, Authy, OTP Auth)

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

## Demo 1: Browser-Flow duplizieren

Built-in Flows sollten nie direkt editiert werden -- deshalb duplizieren wir zuerst.

### Schritt 1 -- Flow-Liste öffnen

1. Navigiere zu **Authentication** (linke Navigation)
2. Du siehst die Liste der vordefinierten Flows

### Schritt 2 -- Browser-Flow duplizieren

1. Klicke bei **browser** auf die drei Punkte -> **Duplicate**
2. Gib als Name ein: `Browser mit MFA`
3. Klicke auf **Duplicate**

> **Zeigen:** Der duplizierte Flow hat dieselbe Struktur wie das Original. Built-in Flows
> sind schreibgeschützt -- Duplikate können frei bearbeitet werden.

---

## Demo 2: OTP auf Required setzen

In der Übung werden die Teilnehmer *Conditional OTP* (nur für Admins) konfigurieren. Hier
zeigen wir den Unterschied: **OTP für jeden User erzwingen**.

### Schritt 1 -- Flow-Struktur analysieren

Öffne den Flow **Browser mit MFA**. Die Struktur:

```text
Browser mit MFA
+-- Cookie                                    (Alternative)
+-- Kerberos                                  (Disabled)
+-- Identity Provider Redirector              (Alternative)
+-- Browser mit MFA forms                     (Alternative)
    +-- Username Password Form                (Required)
    +-- Browser mit MFA Browser - Conditional OTP  (Conditional)
        +-- Condition - User Configured       (Required)
        +-- OTP Form                          (Required)
```

### Schritt 2 -- Conditional OTP auf Required ändern

1. Finde den Subflow **Browser mit MFA Browser - Conditional OTP**
2. Ändere das Requirement von **Conditional** auf **Required**

**Vorher:**

| Execution | Requirement |
| :--- | :--- |
| Browser mit MFA Browser - Conditional OTP | Conditional |

**Nachher:**

| Execution | Requirement |
| :--- | :--- |
| Browser mit MFA Browser - Conditional OTP | **Required** |

> **Zeigen:** Der Unterschied zwischen Conditional und Required:
>
> - **Conditional:** OTP wird nur abgefragt, wenn der User es bereits konfiguriert hat
> - **Required:** OTP wird immer abgefragt -- wer es noch nicht hat, muss es einrichten

**Diskussionspunkte:**

- Wann Conditional, wann Required?
- Was passiert mit Usern, die kein Smartphone haben?

---

## Demo 3: Flow binden

Der neue Flow muss als aktiver Browser-Flow gesetzt werden.

### Schritt 1 -- Flow binden

1. Stelle sicher, dass du den Flow **Browser mit MFA** geöffnet hast
2. Klicke oben auf **Action** -> **Bind flow**
3. Wähle den Binding Type **Browser flow**
4. Klicke auf **Save**

> **Zeigen:** Ab jetzt gilt der neue Flow für alle Browser-Logins im Realm. Der alte Flow bleibt als Backup erhalten.

---

## Demo 4: Login testen

### Schritt 1 -- Account Console öffnen

1. Öffne ein **Inkognito-Fenster**
2. Navigiere zu: <http://localhost:9090/realms/mustertech/account>
3. Klicke auf **Sign in**

### Schritt 2 -- Login mit Passwort

1. Gib Username `alice` und Passwort `demo1234` ein
2. Nach dem erfolgreichen Passwort-Check erscheint die **OTP-Setup-Seite**

### Schritt 3 -- OTP einrichten

1. Scanne den QR-Code mit der Authenticator-App
2. Gib den 6-stelligen Code ein
3. Klicke auf **Submit**

> **Zeigen:** Jeder User -- unabhängig von seiner Rolle -- muss jetzt OTP einrichten. Das
> ist der Unterschied zur Übung, wo nur Admins OTP brauchen.

### Schritt 4 -- Re-Login testen

1. Melde dich ab
2. Melde dich erneut an
3. Nach Username/Passwort wird direkt der OTP-Code abgefragt (kein Setup mehr)

---

## Aufräumen

```bash
docker compose down -v
```
