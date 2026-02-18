# Modul 06c: Client Roles & Isolation -- Gitea mit Keycloak

## Übungsziel

Am Ende dieser Übung hast du:

- **Client Roles** auf einem bestehenden Client erstellt und Benutzern zugewiesen
- Einen `User Client Role`-Mapper im **Dedicated Client Scope** konfiguriert
- Rollenbasierte Zugriffsbeschränkung über einen **Required Claim** getestet
- Einen zweiten Client (`crm-app`) erstellt und die **Client Role Isolation** per Token-Vergleich verifiziert

**Geschätzte Dauer:** 30-40 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet

### Umgebung starten

```bash
cd assignments/modul-06c-gitea-oidc
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details siehe
> [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

Warte bis alle Services bereit sind (~90 Sekunden). Der Realm "mustertech" wird automatisch
importiert. Prüfe den Setup-Container:

```bash
docker compose logs -f assignment-setup
# -> "=== Setup complete ===" abwarten, dann Ctrl+C
```

### Architektur

```
Browser --> Gitea (Port 3000) --> Keycloak (Port 8080) --> PostgreSQL
```

| Service | URL | Zugangsdaten |
| :--- | :--- | :--- |
| Keycloak Admin-Konsole | <http://localhost:8080> | `admin` / `admin` |
| Gitea | <http://localhost:3000> | Login via Keycloak |

### Testbenutzer

| User | Passwort | Realm Roles |
| :--- | :--- | :--- |
| `hans.mueller` | `test1234` | `mitarbeiter` (über Gruppe) |
| `anna.schmidt` | `test1234` | `mitarbeiter` (über Gruppe) |
| `max.admin` | `test1234` | `admin` (inkl. `manager`, `mitarbeiter`) |

> **Ausgangslage:** Die Benutzer haben **keine Client Roles** -- diese erstellst du selbst.

---

## Teil 1: Ausgangslage verstehen (~5 Min)

### Schritt 1.1: Gitea öffnen und Login versuchen

1. Öffne Gitea: <http://localhost:3000>
2. Klicke auf  **Sign in** -> **Sign in with Keycloak**
3. Melde dich an:
   - Username: `hans.mueller`
   - Passwort: `test1234`

**Erwartetes Ergebnis:** Der Login **schlägt fehl**.

> **Warum?** Gitea ist so konfiguriert, dass der Token den Claim `roles` mit dem Wert `gitea-user`
> enthalten muss (**Required Claim**). Da noch keine Client Roles existieren und kein Mapper
> konfiguriert ist, fehlt dieser Claim im Token.

### Schritt 1.2: Required Claim in Gitea ansehen

Woher kommt die Anforderung, dass die Rollen im `roles`-Claim zu sein haben?
Das ist in Gitea konfiguriert.

1. Öffne <http://localhost:3000/-/admin/auths> (Gitea Site Administration)
2. Melde dich mit dem Gitea-Admin-Account an: `gitea-admin` / `admin1234`
3. Klicke auf die Authentication Source **keycloak**

Beachte die Felder:

| Feld                 | Wert         | Bedeutung                            |
|:---------------------|:-------------|:-------------------------------------|
| Required Claim Name  | `roles`      | Gitea prüft diesen Claim im Token    |
| Required Claim Value | `gitea-user` | Der Claim muss diesen Wert enthalten |

> Solange der Token keinen `roles`-Claim mit dem Wert `gitea-user` enthält,
> verweigert Gitea den Zugang - egal ob die Keycloak-Anmeldung erfolgreich war.

### Schritt 1.3: Gitea-Client in Keycloak ansehen

1. Öffne die Admin-Konsole: <http://localhost:8080>
2. Wähle den Realm **mustertech**
3. Navigiere zu **Clients** -> **gitea**

Nimm die Einstellungen zur Kenntnis:

| Feld | Wert | Bedeutung |
| :--- | :--- | :--- |
| Client authentication | ON | Confidential Client (hat ein Secret) |
| Standard flow | Enabled | Authorization Code Flow |
| Root URL | `http://localhost:3000` | Basis-URL von Gitea |
| Valid redirect URIs | `http://localhost:3000/user/oauth2/keycloak/callback` | Callback nach Login |

4. Wechsle zum Tab **Roles** -- die Liste ist leer.

---

## Teil 2: Client Roles für Gitea erstellen

### Schritt 2.1: Rollen anlegen

1. Bleibe im Client **gitea**, Tab **Roles**
2. Klicke auf **Create role**
3. Erstelle die Rolle:
   - Role name: `gitea-user`
   - Description: `Berechtigt zur Anmeldung bei Gitea`
4. Klicke **Save**
5. Gehe zurück zur Rollen-Liste und erstelle eine zweite Rolle:
   - Role name: `gitea-admin`
   - Description: `Gitea-Administrationsrechte`

### Schritt 2.2: Rollen zuweisen

1. Navigiere zu **Users** -> **hans.mueller**
2. Wechsle zum Tab **Role mapping**
3. Klicke auf **Assign role -> Client roles**
4. Suche nach `gitea` und weise `gitea-user` zu

5. Wiederhole für **max.admin** und weise zu:
   - `gitea-user`
   - `gitea-admin`

> **anna.schmidt** bekommt bewusst **keine** Gitea-Rolle.

### Schritt 2.3: Erneuter Login-Versuch

1. Gehe zurück zu Gitea: <http://localhost:3000>
2. Klicke auf  **Sign in** -> **Sign in with Keycloak**
3. Melde dich als `hans.mueller` an

**Erwartetes Ergebnis:** Der Login schlägt **immer noch fehl**.

> **Warum?** Die Rollen existieren zwar und sind zugewiesen, aber es gibt noch keinen
> **Protocol Mapper**, der sie in den Token schreibt. Ohne Mapper kein `roles`-Claim.

---

## Teil 3: Protocol Mapper konfigurieren

### Schritt 3.1: Mapper im Dedicated Scope anlegen

Jeder Client hat automatisch einen **Dedicated Client Scope** (z.B. `gitea-dedicated`).
Dieser Scope gehört exklusiv zum Client und ist der richtige Ort für client-spezifische Mapper.

1. Navigiere zu **Clients** -> **gitea** -> Tab **Client scopes**
2. Klicke auf **gitea-dedicated**
3. Wechsle zum Tab **Mappers**
4. Klicke auf **Configure a new mapper** (oder **Add mapper** -> **By configuration**)
5. Wähle **User Client Role**
6. Konfiguriere:

| Feld                | Wert                 |
|:--------------------|:---------------------|
| Name                | `gitea-client-roles` |
| Client ID           | `gitea`              |
| Multivalued         | ON                   |
| Token Claim Name    | `roles`              |
| Add to ID token     | ON                   |
| Add to access token | ON                   |
| Add to userinfo     | ON                   |

7. Klicke **Save**

> **Wichtig:** Der Mapper ist auf `Client ID = gitea` eingeschränkt. Das bedeutet:
> Wenn Gitea ein Token bekommt, enthält der `roles`-Claim **nur** Gitea-Rollen.

### Schritt 3.2: Login testen

1. Gehe zurück zu Gitea: <http://localhost:3000>
2. Klicke auf **Sign in** -> **Sign in with Keycloak**
3. Melde dich als `hans.mueller` an

**Erwartetes Ergebnis:** Der Login **funktioniert**! Hans hat die Rolle `gitea-user`,
der Mapper schreibt sie in den `roles`-Claim, und Gitea akzeptiert den Required Claim.

### Schritt 3.3: Login als anna.schmidt

1. Öffne ein privates Browserfenster und öffne Gitea unter <http://localhost:3000>
2. Melde dich über Keycloak an mit:
   - Username: `anna.schmidt`
   - Passwort: `test1234`

**Erwartetes Ergebnis:** Der Login **schlägt fehl**. anna.schmidt hat keine `gitea-user`
Client Role, daher fehlt der Required Claim.

> Gitea prüft, ob der Token den Claim `roles` mit dem Wert `gitea-user` enthält.
> Da der scoped Mapper nur Gitea-Client-Roles in den `roles`-Claim schreibt und
> anna.schmidt keine hat, wird sie abgewiesen.

---

## Teil 4: Zweiten Client zum Test der Isolation einrichten

### Schritt 4.1: Client crm-app erstellen

1. Navigiere zu **Clients** -> **Create client**
2. Konfiguriere:

| Schritt           | Feld                  | Wert              |
|:------------------|:----------------------|:------------------|
| General Settings  | Client ID             | `crm-app`         |
| General Settings  | Name                  | `CRM Application` |
| Capability config | Client authentication | **ON**            |
| Capability config | Standard flow         | Enabled           |
| Login settings    | Valid redirect URIs   | `*`               |
| Login settings    | Web origins           | `*`               |

### Schritt 4.2: CRM Client Roles erstellen

1. Wechsle zum Tab **Roles**
2. Erstelle:
   - `crm-viewer`
   - `crm-editor`

### Schritt 4.3: CRM-Rollen zuweisen

Erstelle folgende Rollenzuweisungen:

| Benutzer       | CRM-Rollen                 |
|:---------------|:---------------------------|
| `hans.mueller` | `crm-viewer`               |
| `anna.schmidt` | `crm-editor`, `crm-viewer` |
| `max.admin`    | `crm-viewer`               |

### Schritt 4.4: Mapper in crm-app-dedicated konfigurieren

1. Navigiere zu **Clients** -> **crm-app** -> Tab **Client scopes**
2. Klicke auf **crm-app-dedicated**
3. Wechsle zum Tab **Mappers** -> **Configure a new mapper** -> **User Client Role**
4. Konfiguriere:

| Feld                | Wert               |
|:--------------------|:-------------------|
| Name                | `crm-client-roles` |
| Client ID           | `crm-app`          |
| Multivalued         | ON                 |
| Token Claim Name    | `roles`            |
| Add to ID token     | ON                 |
| Add to access token | ON                 |
| Add to userinfo     | ON                 |

---

## Teil 5: Token evaluieren

Keycloak bietet eine eingebaute **Evaluate**-Funktion, mit der du Tokens direkt in der
Admin-Konsole anschauen kannst.

### Schritt 5.1: Gitea-Token für max.admin evaluieren

1. Navigiere zu **Clients** -> **gitea** -> Tab **Client scopes**
2. Klicke auf den Sub-Tab **Evaluate**
3. Wähle bei **Users** den Benutzer `max.admin` aus
4. Klicke auf **Generated ID Token**

Der `roles`-Claim enthält **nur** Gitea-Rollen - keine CRM-Rollen, obwohl max.admin
auch `crm-viewer` hat.

Testweise kannst du im Protocol Mapper für den Roles-Claim die Client ID entfernen.
Daraufhin werden alle Rollen im Token angezeigt, auch die, die nicht zum Client gehören.

## Zusammenfassung

Du hast erfolgreich:

- [x] **Client Roles** auf dem gitea-Client erstellt (`gitea-user`, `gitea-admin`)
- [x] Einen `User Client Role`-Mapper im **Dedicated Client Scope** konfiguriert
- [x] Login mit und ohne Client Role getestet (anna.schmidt wird abgewiesen)
- [x] Einen zweiten Client (`crm-app`) mit eigenen Client Roles erstellt
- [x] Die **Client Role Isolation** per Token-Vergleich verifiziert:
  Gitea-Token enthält nur Gitea-Rollen, CRM-Token nur CRM-Rollen
