# Live-Demo: Modul 08 — Zugriffskontrolle & Authorization Services

Authorization Services mit **Time Policy** und **Aggregated Policy** zeigen — im Gegensatz zur Übung, die reine Role-Policies für `urlaubsantrag`/`admin-bereich` nutzt.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Authorization Services aktivieren | 2 Min |
| Demo 2 | Resource & Policies erstellen | 4 Min |
| Demo 3 | Permission verknüpfen | 2 Min |
| Demo 4 | Evaluate testen | 3 Min |

## Voraussetzungen

- Keycloak läuft (Realm **mustertech** existiert)
- Admin-Konsole erreichbar unter <http://localhost:8080>
- Mindestens ein User mit der Rolle `manager` vorhanden (z.B. max.admin aus Modul 04)
- Mindestens ein User **ohne** Manager-Rolle (z.B. hans.mueller)

---

## Demo 1: Authorization Services aktivieren

### Schritt 1 — Confidential Client erstellen

1. Navigiere zu **Clients** → **Create client**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Client type | OpenID Connect |
| Client ID | `demo-api` |

3. Klicke auf **Next**
4. Aktiviere:
   - **Client authentication:** ON
   - **Authorization:** ON
5. Klicke auf **Next** → **Save**

### Schritt 2 — Authorization Tab erkunden

Nach dem Speichern erscheint der Tab **Authorization** mit:

- **Resources** — Was wird geschützt?
- **Scopes** — Was darf man tun?
- **Policies** — Wer darf es / wann?
- **Permissions** — Die Verknüpfung
- **Evaluate** — Test-Tool

> **Zeigen:** Authorization Services sind nur für Confidential Clients verfügbar. Der Tab erscheint erst nach dem Aktivieren.

---

## Demo 2: Resource und Policies erstellen

### Schritt 1 — Resource "Sensitive Data" erstellen

1. **Authorization** → **Resources** → **Create resource**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `sensitive-data` |
| Display name | `Sensitive Data` |
| Type | `urn:demo-api:resource:sensitive` |
| URI | `/api/sensitive/*` |

3. Klicke auf **Save**

### Schritt 2 — Time Policy "Working Hours" erstellen

1. **Authorization** → **Policies** → **Create policy** → **Time**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Working Hours` |
| Not before hour | `8` |
| Not on or after hour | `17` |
| Logic | Positive |

3. Klicke auf **Save**

> **Zeigen:** Die Time Policy prüft die aktuelle Uhrzeit. Außerhalb von 8-17 Uhr liefert sie DENY. Das ist etwas, das mit reinem RBAC nicht möglich wäre.

### Schritt 3 — Role Policy "Is Manager" erstellen

1. **Authorization** → **Policies** → **Create policy** → **Role**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Is Manager` |
| Realm roles | `manager` |
| Logic | Positive |

3. Klicke auf **Save**

### Schritt 4 — Aggregated Policy erstellen

1. **Authorization** → **Policies** → **Create policy** → **Aggregated**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Manager During Working Hours` |
| Apply policy | `Working Hours`, `Is Manager` |
| Decision strategy | **Unanimous** |
| Logic | Positive |

3. Klicke auf **Save**

> **Zeigen:** Unanimous bedeutet: **Beide** Policies müssen PERMIT liefern. Der User muss Manager sein UND es muss zwischen 8-17 Uhr sein.

**Diskussionspunkte:**

- Was wäre bei "Affirmative" statt "Unanimous"? (Eine der beiden reicht)
- Welche anderen Policy-Typen gibt es? (User, Group, Client, JavaScript)

---

## Demo 3: Permission erstellen

### Schritt 1 — Resource-Based Permission

1. **Authorization** → **Permissions** → **Create permission** → **Resource-based**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `Access Sensitive Data` |
| Resources | `sensitive-data` |
| Policies | `Manager During Working Hours` |
| Decision strategy | Unanimous |

3. Klicke auf **Save**

> **Zeigen:** Die Permission verbindet die Resource mit der Aggregated Policy. Ergebnis: "Sensitive Data" darf nur von Managern während der Arbeitszeit zugegriffen werden.

---

## Demo 4: Evaluate testen

### Schritt 1 — Evaluate als Manager

1. **Authorization** → **Evaluate**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| User | `max.admin` (hat Rolle manager) |
| Resources | `sensitive-data` |

3. Klicke auf **Evaluate**

**Erwartetes Ergebnis:**

- Falls zwischen 8-17 Uhr: **PERMIT**
- Falls außerhalb: **DENY**

### Schritt 2 — Evaluate als normaler User

1. Ändere den User auf `hans.mueller` (kein Manager)
2. Klicke auf **Evaluate**

**Erwartetes Ergebnis:** **DENY** — unabhängig von der Uhrzeit.

### Schritt 3 — Policy-Details anzeigen

1. Klicke auf das Ergebnis, um die Details zu sehen
2. Keycloak zeigt, welche Policy PERMIT und welche DENY geliefert hat

> **Zeigen:** Das Evaluate-Tool ist essenziell für Debugging. Man sieht exakt, welche Policy den Zugriff blockiert — ohne Code schreiben zu müssen.

### Schritt 4 — Time Policy anpassen (Optional)

Falls die Demo außerhalb der Arbeitszeit stattfindet:

1. Öffne die Policy **Working Hours**
2. Ändere die Uhrzeiten, sodass die aktuelle Uhrzeit eingeschlossen ist
3. Speichere und evaluiere erneut → jetzt PERMIT für Manager

**Diskussionspunkte:**

- Wie integriert eine API das in der Praxis? (UMA-Ticket-Grant, RPT)
- Kann man Policies ohne Neustart der App ändern? (Ja — zentral in Keycloak)
- Wann RBAC, wann ABAC? (RBAC für 80% der Fälle, ABAC für dynamische Regeln)

---

## Aufräumen

1. Client **demo-api** löschen (**Clients** → **demo-api** → **Action** → **Delete**)
