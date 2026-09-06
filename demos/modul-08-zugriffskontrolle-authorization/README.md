# Live-Demo Modul 08: Zugriffskontrolle & Authorization Services

Authorization Services mit **Time Policy** und **Aggregated Policy** zeigen, anders als
die Übung, die reine Role-Policies für `urlaubsantrag`/`admin-bereich` nutzt.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Authorization Services aktivieren | 2 Min |
| Demo 2 | Resource & Policies erstellen | 4 Min |
| Demo 3 | Permission verknüpfen | 2 Min |
| Demo 4 | Evaluate testen | 3 Min |

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

Der Realm **mustertech** wird automatisch importiert mit:

- Realm Role `manager`
- User `max.admin` (hat Rolle `manager`, Passwort: `demo1234`)
- User `hans.mueller` (keine Manager-Rolle, Passwort: `demo1234`)

---

## Demo 1: Authorization Services aktivieren

### Schritt 1: Confidential Client erstellen

1. Navigiere zu **Clients** -> **Create client**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Client type | OpenID Connect |
| Client ID | `demo-api` |

3. Klicke auf **Next**
4. Aktiviere:
   - **Client authentication:** ON
   - **Authorization:** ON
5. Klicke auf **Next** -> **Save**

### Schritt 2: Authorization Tab erkunden

Nach dem Speichern erscheint der Tab **Authorization** mit:

- **Resources:** Was wird geschützt?
- **Scopes:** Was darf man tun?
- **Policies:** Wer darf es / wann?
- **Permissions:** Die Verknüpfung
- **Evaluate:** Test-Tool

> **Zeigen:** Authorization Services sind nur für Confidential Clients verfügbar. Der Tab
> erscheint erst nach dem Aktivieren.

---

## Demo 2: Resource und Policies erstellen

### Schritt 1: Resource "Sensitive Data" erstellen

1. **Authorization** -> **Resources** -> **Create resource**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `sensitive-data` |
| Display name | `Sensitive Data` |
| Type | `urn:demo-api:resource:sensitive` |
| URI | `/api/sensitive/*` |

3. Klicke auf **Save**

### Schritt 2: Time Policy "Working Hours" erstellen

1. **Authorization** -> **Policies** -> **Create policy** -> **Time**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Working Hours` |
| Repeat | **Repeat** |
| Month | `1` bis `12` |
| Day | `1` bis `31` |
| Hour | `8` bis `17` |
| Minute | `0` bis `59` |
| Start time | `2025-01-01` / `0:00` |
| Expire time | `2099-12-31` / `23:59` |
| Logic | Positive |

3. Klicke auf **Save**

> **Zeigen:** Die Time Policy kombiniert zwei Ebenen:
>
> - **Start/Expire time:** der Gesamtzeitraum, in dem die Policy aktiv ist
>   (Pflichtfelder). Z.B. "Externer Berater darf nur bis 31.03. zugreifen."
> - **Repeat-Felder** (Hour, Day, Month, Minute): wiederkehrende Einschränkungen
>   innerhalb dieses Zeitraums. Z.B. "nur Mo-Fr 8-17 Uhr."
>
> Für unsere Demo setzen wir den Gesamtzeitraum bewusst weit (2025-2099) und schränken nur
> die Stunden ein. Das ermöglicht dynamische zeitliche Regeln, die mit reinem RBAC nicht
> möglich wären.

### Schritt 3: Role Policy "Is Manager" erstellen

1. **Authorization** -> **Policies** -> **Create policy** -> **Role**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Is Manager` |
| Realm roles | `manager` |
| Logic | Positive |

3. Klicke auf **Save**

### Schritt 4: Aggregated Policy erstellen

1. **Authorization** -> **Policies** -> **Create policy** -> **Aggregated**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Manager During Working Hours` |
| Apply policy | `Working Hours`, `Is Manager` |
| Decision strategy | **Unanimous** |
| Logic | Positive |

3. Klicke auf **Save**

> **Zeigen:** Unanimous bedeutet: **Beide** Policies müssen PERMIT liefern. Der User muss
> Manager sein UND es muss zwischen 8-17 Uhr sein.

**Diskussionspunkte:**

- Was wäre bei "Affirmative" statt "Unanimous"? (Eine der beiden reicht)
- Welche anderen Policy-Typen gibt es? (User, Group, Client, JavaScript)

---

## Demo 3: Permission erstellen

### Schritt 1: Resource-Based Permission

1. **Authorization** -> **Permissions** -> **Create permission** -> **Resource-based**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Access Sensitive Data` |
| Resources | `sensitive-data` |
| Policies | `Manager During Working Hours` |
| Decision strategy | Unanimous |

3. Klicke auf **Save**

> **Zeigen:** Die Permission verbindet die Resource mit der Aggregated Policy. Ergebnis:
> "Sensitive Data" darf nur von Managern während der Arbeitszeit zugegriffen werden.

---

## Demo 4: Evaluate testen

### Schritt 1: Evaluate als Manager

1. **Authorization** -> **Evaluate**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| User | `max.admin` (hat Rolle manager) |
| Resources | `sensitive-data` |

3. Klicke auf **Evaluate**

**Erwartetes Ergebnis:**

- Falls zwischen 8-17 Uhr: **PERMIT**
- Falls außerhalb: **DENY**

### Schritt 2: Evaluate als normaler User

1. Ändere den User auf `hans.mueller` (kein Manager)
2. Klicke auf **Evaluate**

**Erwartetes Ergebnis:** **DENY**, unabhängig von der Uhrzeit.

### Schritt 3: Policy-Details anzeigen

1. Klicke auf das Ergebnis, um die Details zu sehen
2. Keycloak zeigt, welche Policy PERMIT und welche DENY geliefert hat

> **Zeigen:** Das Evaluate-Tool ist essenziell für Debugging. Man sieht exakt, welche
> Policy den Zugriff blockiert, ohne Code schreiben zu müssen.

### Schritt 4: Time Policy anpassen (Optional)

Falls die Demo außerhalb der Arbeitszeit stattfindet:

1. Öffne die Policy **Working Hours**
2. Ändere die Uhrzeiten, sodass die aktuelle Uhrzeit eingeschlossen ist
3. Speichere und evaluiere erneut -> jetzt PERMIT für Manager

**Diskussionspunkte:**

- Wie integriert eine API das in der Praxis? (UMA-Ticket-Grant, RPT)
- Kann man Policies ohne Neustart der App ändern? (Ja, zentral in Keycloak)
- Wann RBAC, wann ABAC? (RBAC für 80% der Fälle, ABAC für dynamische Regeln)

---

## Aufräumen

```bash
docker compose down -v
```
