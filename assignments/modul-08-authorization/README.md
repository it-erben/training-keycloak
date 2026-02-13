# Modul 08: Zugriffskontrolle & Authorization Services

## Übungsziel

Am Ende dieser Übung hast du:

- Authorization Services für die Portal-API aktiviert
- Ressourcen und Scopes definiert
- Policies basierend auf Rollen erstellt
- Permissions konfiguriert und getestet

**Geschätzte Dauer:** 25-30 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet

### Umgebung starten

```bash
cd assignments/modul-08-authorization
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe diese zuerst mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details siehe [Troubleshooting](#container-name-konflikt).

Warte bis Keycloak, Portal-Frontend und Portal-API bereit sind (~60 Sekunden). Der Realm "mustertech" wird automatisch importiert mit allen Clients und Konfigurationen aus den vorherigen Modulen.

---

## Teil 1: Authorization Services aktivieren

### Schritt 1.1: Client konfigurieren

1. Admin-Konsole -> **Clients** -> **portal-api**
2. Wechsle zum Tab **Settings**
3. Scrolle zu **Capability config**
4. Aktiviere **Authorization**: **ON**
5. Klicke auf **Save**

### Schritt 1.2: Authorization Tab erkunden

Nach dem Aktivieren erscheint ein neuer Tab **Authorization** mit:

- **Settings**: Grundeinstellungen
- **Resources**: Geschützte Ressourcen
- **Scopes**: Aktionen auf Ressourcen
- **Policies**: Bedingungen für Zugriff
- **Permissions**: Verknüpfung von Ressourcen, Scopes und Policies

---

## Teil 2: Ressourcen definieren

### Schritt 2.1: Ressource "Urlaubsantrag" erstellen

1. **Authorization** -> **Resources** -> **Create resource**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `urlaubsantrag` |
| Display name | `Urlaubsantrag` |
| Type | `urn:portal-api:resource:urlaubsantrag` |
| URI | `/api/urlaubsantraege/*` |

Klicke auf **Save**.

### Schritt 2.2: Ressource "Admin-Bereich" erstellen

| Feld         | Wert                            |
|:-------------|:--------------------------------|
| Name         | `admin-bereich`                 |
| Display name | `Admin-Bereich`                 |
| Type         | `urn:portal-api:resource:admin` |
| URI          | `/api/admin/*`                  |

---

## Teil 3: Scopes definieren

### Schritt 3.1: Scopes erstellen

1. **Authorization** -> **Scopes** -> **Create authorization scope**
2. Erstelle folgende Scopes:

| Name      | Display name |
|:----------|:-------------|
| `view`    | Anzeigen     |
| `create`  | Erstellen    |
| `approve` | Genehmigen   |

### Schritt 3.2: Scopes zu Ressourcen zuweisen

1. Öffne Ressource **urlaubsantrag**
2. Unter **Authorization scopes** wähle: `view`, `create`, `approve`
3. Speichern

Füge analog "view" zur Ressource "admin-bereich" hinzu.

---

## Teil 4: Policies erstellen

### Schritt 4.1: Policy für Mitarbeiter

1. **Authorization** -> **Policies** -> **Create client policy** -> **Role**
2. Konfiguriere:

| Feld  | Wert                         |
|:------|:-----------------------------|
| Name  | `Mitarbeiter Policy`         |
| Roles | Realm Roles -> `mitarbeiter` |
| Logic | Positive                     |

### Schritt 4.2: Policy für Manager

| Feld | Wert                     |
| :--- |:-------------------------|
| Name | `Manager Policy`         |
| Roles | Realm roles -> `manager` |
| Logic | Positive                 |

### Schritt 4.3: Policy für Admins

| Feld | Wert |
| :--- | :--- |
| Name | `Admin Policy` |
| Roles | `admin` |
| Logic | Positive |

---

## Teil 5: Permissions erstellen

### Schritt 5.1: Permission für Urlaubsanträge anzeigen

1. **Authorization** -> **Permissions** -> **Create scope-based permission**
2. Konfiguriere:

| Feld | Wert |
| :--- | :--- |
| Name | `View Urlaubsanträge` |
| Resources | `urlaubsantrag` |
| Scopes | `view` |
| Policies | `Mitarbeiter Policy` |
| Decision strategy | Unanimous |

> **Decision Strategy** bestimmt, wie Keycloak mehrere Policies einer Permission
> auswertet:
>
> | Strategy | Bedeutung |
> | :--------- | :---------- |
> | **Unanimous** | **Alle** zugeordneten Policies müssen PERMIT liefern. Verweigert eine einzige Policy, wird der Zugriff abgelehnt. Strengste Variante -- sinnvoll, wenn jede Bedingung zwingend erfüllt sein muss. |
> | **Affirmative** | **Mindestens eine** Policy muss PERMIT liefern. Sobald eine Policy zustimmt, wird der Zugriff gewährt -- auch wenn andere Policies DENY liefern. |
> | **Consensus** | Die **Mehrheit** entscheidet. Liefern mehr Policies PERMIT als DENY, wird der Zugriff gewährt. Bei Gleichstand wird abgelehnt. |
>
> Bei nur einer Policy pro Permission verhalten sich alle drei Strategien identisch.

### Schritt 5.2: Permission für Urlaubsanträge genehmigen

| Feld | Wert |
| :--- | :--- |
| Name | `Approve Urlaubsanträge` |
| Resources | `urlaubsantrag` |
| Scopes | `approve` |
| Policies | `Manager Policy` |
| Decision strategy | Unanimous |

### Schritt 5.3: Permission für Admin-Bereich

| Feld | Wert |
| :--- | :--- |
| Name | `Access Admin` |
| Resources | `admin-bereich` |
| Scopes | `view` |
| Policies | `Admin Policy` |
| Decision strategy | Unanimous |

---

## Teil 6: Permissions testen

### Schritt 6.1: Evaluate Tool nutzen

1. **Authorization** -> **Evaluate**
2. Wähle einen User (z.B. hans.mueller)
3. Wähle die passende Rolle (z.B. mitarbeiter)
3. Wähle Ressource und Scope
4. Klicke auf **Evaluate**

**Erwartete Ergebnisse:**

| User         | Ressource     | Scope   | Ergebnis |
|:-------------|:--------------|:--------|:---------|
| hans.mueller | urlaubsantrag | view    | PERMIT   |
| hans.mueller | urlaubsantrag | approve | DENY     |
| max.admin    | urlaubsantrag | approve | PERMIT   |
| max.admin    | admin-bereich | view    | PERMIT   |

---

## Teil 7: API Integration -- Permissions im Portal testen

Bisher haben wir Permissions nur im **Evaluate-Tool** der Admin-Konsole getestet. Jetzt schalten wir die echte Integration ein: Die Portal-API fragt Keycloak bei jedem Request, ob der User die nötige Permission besitzt.

### Hintergrund: UMA-Ticket-Grant

Die API nutzt den **UMA (User-Managed Access) Ticket Grant**. Der Ablauf:

1. Der User schickt seinen Access Token an die API
2. Die API schickt diesen Token an Keycloak weiter und fragt: *"Darf dieser User `urlaubsantrag#view`?"*
3. Keycloak evaluiert alle relevanten Policies
4. Keycloak antwortet mit `{ "result": true }` oder verweigert

```
User -> API -> Keycloak Authorization Endpoint
                |
          Policies evaluieren
                |
         { "result": true/false }
                |
       API: 200 OK / 403 Forbidden
```

Der Vorteil: **Die API kennt keine Rollen mehr.** Ob ein User zugreifen darf, entscheidet allein Keycloak -- zentral, konfigurierbar, ohne Code-Änderung.

### Schritt 7.1: Authorization in docker-compose.yml aktivieren

Die Portal-API enthält bereits eine `requirePermission()`-Middleware, die per Umgebungsvariable aktiviert wird.

1. Öffne die `docker-compose.yml` in diesem Verzeichnis
2. Füge beim Service **assignment-api** eine Zeile hinzu:

```yaml
  assignment-api:
    # ...
    environment:
      - API_PORT=3001
      - VITE_KEYCLOAK_URL=http://assignment-keycloak:8080
      - KEYCLOAK_PUBLIC_URL=http://localhost:8080
      - VITE_KEYCLOAK_REALM=mustertech
      - AUTHORIZATION_ENABLED=true          # <- diese Zeile hinzufügen
```

### Schritt 7.2: API neu starten

```bash
docker compose up -d --build assignment-api
```

### Schritt 7.3: Testen

1. Melde dich im Portal als **hans.mueller** (Mitarbeiter) an
2. Klicke auf **Urlaubsanträge** -> sollte funktionieren (`urlaubsantrag#view` = PERMIT)
3. Navigiere zu **Alle Anträge** -> sollte **403** liefern (`urlaubsantrag#approve` = DENY)

Melde dich als **max.admin** an und prüfe, dass der Admin-Bereich erreichbar ist.

### Schritt 7.4: Live-Änderung -- Policy deaktivieren

1. Gehe in die Admin-Konsole -> **Clients** -> **portal-api** -> **Authorization** -> **Policies**
2. Öffne die **Mitarbeiter Policy**
3. Ändere die **Logic** von **Positive** auf **Negative**
4. Speichere

Teste erneut als **hans.mueller**:

- **Urlaubsanträge** -> jetzt **403 Forbidden**!

Setze die Policy wieder auf **Positive** zurück -- der Zugriff funktioniert sofort wieder.

> **Erkenntnis:** Kein Rebuild, kein Redeploy, kein Code-Change. Die Zugriffsentscheidung liegt in Keycloak.

## Zusammenfassung

Du hast erfolgreich:

- [x] Authorization Services aktiviert
- [x] Ressourcen (Urlaubsantrag, Admin-Bereich) definiert
- [x] Scopes (view, create, approve) erstellt
- [x] Role-based Policies konfiguriert
- [x] Permissions erstellt und getestet
- [x] Die API mit Keycloak Authorization Services verbunden
- [x] Live-Änderungen an Policies ohne Code-Änderung erlebt

**Nächstes Modul:** Anpassung - Theming, APIs & SPIs (Modul 09)!

---

## Troubleshooting

### Container-Name-Konflikt

**Symptom:** Beim Start erscheint ein Fehler wie:

```
Error response from daemon: Conflict. The container name "/assignment-postgres" is already
in use by container "...". You have to remove (or rename) that container to be able to
reuse that name.
```

**Ursache:** Die Container einer vorherigen Übung laufen noch oder wurden nicht vollständig entfernt.

**Lösung:** Wechsle in das Verzeichnis der vorherigen Übung und räume dort auf:

```bash
cd assignments/<vorherige-uebung>
docker compose down -v
```

Danach kannst du die aktuelle Übung normal starten.
