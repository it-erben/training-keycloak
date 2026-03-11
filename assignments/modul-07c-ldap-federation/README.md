# Modul 07c: LDAP Federation

## Übungsziel

Am Ende dieser Übung hast du:

- Einen **LDAP-Verzeichnisdienst** (OpenLDAP) als externe Benutzerquelle
  erkundet
- **User Federation** in Keycloak konfiguriert, um LDAP-Benutzer zu importieren
- Einen **Gruppen-Mapper** eingerichtet, der LDAP-Gruppen nach Keycloak
  synchronisiert
- LDAP-Gruppen auf **Keycloak Realm Roles** gemappt
- Rollen-Claims in **OIDC-Tokens** überprüft

**Geschätzte Dauer:** 30 Minuten

---

## Umgebung starten

```bash
cd assignments/modul-07c-ldap-federation
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe
> diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details
> siehe
> [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

Warte bis alle Services bereit sind (~60 Sekunden). Der Realm "mustertech" wird
automatisch importiert. Prüfe den Setup-Container:

```bash
docker compose logs -f assignment-setup
# -> "=== Setup complete ===" abwarten, dann Ctrl+C
```

### Architektur

```
Browser --> Keycloak (Port 8080) --> PostgreSQL
                |
                +--> OpenLDAP (Port 1389)
```

| Service                  | URL / Adresse                    | Zugangsdaten                             |
|:-------------------------|:---------------------------------|:-----------------------------------------|
| Keycloak Admin-Konsole   | <http://localhost:8080>          | `admin` / `admin`                        |
| OpenLDAP (Docker-intern) | `ldap://assignment-openldap:389` | `cn=admin,dc=mustertech,dc=de` / `admin` |
| OpenLDAP (Host)          | `ldap://localhost:1389`          | `cn=admin,dc=mustertech,dc=de` / `admin` |

### LDAP-Verzeichnisstruktur

```
dc=mustertech,dc=de
├── ou=users
│   ├── uid=hans.mueller    (Hans Mueller, Entwicklung)
│   ├── uid=anna.schmidt    (Anna Schmidt, Vertrieb)
│   └── uid=max.admin       (Max Administrator, Management)
└── ou=groups
    ├── cn=entwicklung      (Mitglied: hans.mueller)
    ├── cn=vertrieb         (Mitglied: anna.schmidt)
    └── cn=management       (Mitglied: max.admin)
```

### Testbenutzer (im LDAP)

| User           | Passwort   | LDAP-Gruppe   |
|:---------------|:-----------|:--------------|
| `hans.mueller` | `test1234` | `entwicklung` |
| `anna.schmidt` | `test1234` | `vertrieb`    |
| `max.admin`    | `test1234` | `management`  |

> **Ausgangslage:** Die Benutzer existieren **nur im LDAP**. In Keycloak gibt es
> noch keine Benutzer im Realm "mustertech" - diese werden über die User Federation
synchronisiert. Die Realm Roles `entwicklung`, `vertrieb` und `management` sind bereits angelegt.

---

## Teil 1: LDAP-Verzeichnis erkunden

### Schritt 1.1: LDAP-Baum anzeigen

Verwende `ldapsearch` im OpenLDAP-Container, um den LDAP-Baum zu erkunden:

**Bash:**

```bash
docker exec assignment-openldap ldapsearch -x \
  -H ldap://localhost \
  -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "dc=mustertech,dc=de" \
  "(objectClass=*)" dn
```

**PowerShell:**

```powershell
docker exec assignment-openldap ldapsearch -x `
  -H ldap://localhost `
  -D "cn=admin,dc=mustertech,dc=de" -w admin `
  -b "dc=mustertech,dc=de" `
  "(objectClass=*)" dn
```

> **Erklärung der Parameter:**
>
> | Parameter | Bedeutung                          |
> |:----------|:-----------------------------------|
> | `-x`      | Simple Authentication (nicht SASL) |
> | `-H`      | LDAP-Server URL                    |
> | `-D`      | Bind DN (Admin-Account)            |
> | `-w`      | Passwort                           |
> | `-b`      | Base DN (Startpunkt der Suche)     |

### Schritt 1.2: Benutzer anzeigen

**Bash:**

```bash
docker exec assignment-openldap ldapsearch -x \
  -H ldap://localhost \
  -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "ou=users,dc=mustertech,dc=de" \
  "(objectClass=inetOrgPerson)"
```

**PowerShell:**

```powershell
docker exec assignment-openldap ldapsearch -x `
  -H ldap://localhost `
  -D "cn=admin,dc=mustertech,dc=de" -w admin `
  -b "ou=users,dc=mustertech,dc=de" `
  "(objectClass=inetOrgPerson)"
```

Beachte die Attribute jedes Benutzers: `uid`, `cn`, `sn`, `givenName`, `mail`.

### Schritt 1.3: Gruppen anzeigen

**Bash:**

```bash
docker exec assignment-openldap ldapsearch -x \
  -H ldap://localhost \
  -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "ou=groups,dc=mustertech,dc=de" \
  "(objectClass=groupOfNames)"
```

**PowerShell:**

```powershell
docker exec assignment-openldap ldapsearch -x `
  -H ldap://localhost `
  -D "cn=admin,dc=mustertech,dc=de" -w admin `
  -b "ou=groups,dc=mustertech,dc=de" `
  "(objectClass=groupOfNames)"
```

Beachte das `member`-Attribut - es enthält den **vollständigen DN** der
Gruppenmitglieder.

> **Konzept: LDAP-Gruppentypen** - LDAP unterstützt verschiedene Gruppen-Typen.
> `groupOfNames` ist der gängigste und speichert Mitgliedschaften als vollständige DNs.
> Keycloak unterstützt zusätzlich `posixGroup` (mit `memberUid`) und `groupOfUniqueNames` (mit `uniqueMember`).

---

## Teil 2: User Federation konfigurieren

### Schritt 2.1: LDAP-Provider hinzufügen

1. Öffne die Keycloak Admin-Konsole: <http://localhost:8080>
2. Wähle den Realm **mustertech**
3. Navigiere zu **User federation**
4. Klicke auf **Add LDAP providers**

### Schritt 2.2: Verbindungseinstellungen konfigurieren

Konfiguriere die folgenden Einstellungen:

**General options:**

| Feld            | Wert              |
|:----------------|:------------------|
| UI display name | `mustertech-ldap` |
| Vendor          | `Other`           |

**Connection and authentication settings:**

| Feld             | Wert                             |
|:-----------------|:---------------------------------|
| Connection URL   | `ldap://assignment-openldap:389` |
| Bind type        | `simple`                         |
| Bind DN          | `cn=admin,dc=mustertech,dc=de`   |
| Bind credentials | `admin`                          |

Klicke auf **Test connection** - es sollte "Successfully connected to LDAP" erscheinen.

Klicke weiter unten auf **Test authentication** - es sollte "Successfully connected to LDAP" erscheinen.

**LDAP searching and updating:**

| Feld                    | Wert                           |
|:------------------------|:-------------------------------|
| Edit mode               | `READ_ONLY`                    |
| Users DN                | `ou=users,dc=mustertech,dc=de` |
| Username LDAP attribute | `uid`                          |
| RDN LDAP attribute      | `uid`                          |
| UUID LDAP attribute     | `entryUUID`                    |
| User object classes     | `inetOrgPerson`                |
| Search scope            | `One Level`                    |

**Sync settings:**

| Feld               | Wert  |
|:-------------------|:------|
| Import users       | `ON`  |
| Sync Registrations | `OFF` |

Klicke **Save**.

> **Konzept: Edit Mode** - `READ_ONLY` bedeutet, dass Keycloak die LDAP-Daten
> nicht verändern kann. Passwort-Änderungen und Profil-Updates müssen direkt im LDAP erfolgen.
> Im Modus `WRITABLE` könnten Änderungen in Keycloak zurück ins LDAP geschrieben werden.

---

## Teil 3: Benutzer synchronisieren und testen

### Schritt 3.1: Vollständige Synchronisation ausführen

1. Gehe in die Einstellungen von `mustertech-ldap` und klicke im oberen Bereich auf **Action** -> **Sync all users**
2. Es sollte eine Meldung erscheinen, dass 3 Benutzer importiert/aktualisiert wurden

### Schritt 3.2: Importierte Benutzer prüfen

1. Navigiere zu **Users**
2. Klicke auf **View all users** und suche nach `*`

Die drei LDAP-Benutzer sollten jetzt sichtbar sein: `hans.mueller`,
`anna.schmidt`, `max.admin`.

3. Klicke auf **hans.mueller** und prüfe:
    - Die Attribute (Vorname, Nachname, E-Mail) wurden aus dem LDAP übernommen
    - Das Feld **Federation link** zeigt `mustertech-ldap` an

### Schritt 3.3: Login testen

1. Öffne ein neues **privates Browserfenster**
2. Gehe zu <http://localhost:8080/realms/mustertech/account/>
3. Melde dich an mit:
    - Username: `hans.mueller`
    - Passwort: `test1234`

**Erwartetes Ergebnis:** Der Login funktioniert - Keycloak authentifiziert den Benutzer gegen das LDAP-Verzeichnis.

---

## Teil 4: Gruppen-Mapper konfigurieren

### Schritt 4.1: Gruppen-Mapper anlegen

1. Navigiere zu **User federation** -> **mustertech-ldap**
2. Wechsle zum Tab **Mappers**
3. Klicke auf **Add mapper**
4. Konfiguriere:

| Feld                                 | Wert                              |
|:-------------------------------------|:----------------------------------|
| Name                                 | `group-mapper`                    |
| Mapper type                          | `group-ldap-mapper`               |
| LDAP Groups DN                       | `ou=groups,dc=mustertech,dc=de`   |
| Group Name LDAP Attribute            | `cn`                              |
| Group Object Classes                 | `groupOfNames`                    |
| Membership LDAP Attribute            | `member`                          |
| Membership Attribute Type            | `DN`                              |
| Membership User LDAP Attribute       | `uid`                             |
| Mode                                 | `READ_ONLY`                       |
| User Groups Retrieve Strategy        | `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE` |
| Drop non-existing groups during sync | `ON`                              |

5. Klicke **Save**

> **Konzept: Group-LDAP-Mapper** - Der Mapper synchronisiert LDAP-Gruppen als
> Keycloak-Gruppen. Die Mitgliedschaft wird über das `member`-Attribut aufgelöst, das den
> vollständigen DN des Benutzers enthält. Im `READ_ONLY`-Modus können Gruppenmitgliedschaften nur
> im LDAP geändert werden.

### Schritt 4.2: Gruppen synchronisieren

1. Gehe in die Einstellungen des neuen Mappers.
2. Klicke im oberen Bereich der Mapper-Seite auf auf **Action** -> **Sync LDAP groups to Keycloak**

### Schritt 4.3: Gruppen in Keycloak prüfen

1. Navigiere zu **Groups**
2. Du siehst jetzt die drei LDAP-Gruppen: `entwicklung`, `vertrieb`,
   `management`
3. Klicke auf **entwicklung** -> Tab **Members**
4. `hans.mueller` sollte als Mitglied aufgelistet sein

Prüfe auch die anderen Gruppen:

| Gruppe        | Erwartetes Mitglied |
|:--------------|:--------------------|
| `entwicklung` | `hans.mueller`      |
| `vertrieb`    | `anna.schmidt`      |
| `management`  | `max.admin`         |

---

## Teil 5: Gruppen auf Realm Roles mappen

Im Realm "mustertech" existieren bereits drei Rollen: `entwicklung`, `vertrieb`
und `management`. Jetzt verknüpfst du die synchronisierten LDAP-Gruppen mit
diesen Rollen.

### Schritt 5.1: Rollen den Gruppen zuweisen

1. Navigiere zu **Groups** -> **entwicklung**
2. Wechsle zum Tab **Role mapping**
3. Klicke auf **Assign role**
4. Wähle die Realm Role **entwicklung** und klicke **Assign**

Wiederhole für die anderen Gruppen:

| Gruppe        | Zuzuweisende Realm Role |
|:--------------|:------------------------|
| `entwicklung` | `entwicklung`           |
| `vertrieb`    | `vertrieb`              |
| `management`  | `management`            |

### Schritt 5.2: Rollen-Zuweisung prüfen

1. Navigiere zu **Users** -> **hans.mueller**
2. Wechsle zum Tab **Role mapping**
3. Lasse dir auch die **inherited roles** anzeigen
4. Die Rolle `entwicklung` erscheint

> **Indirekte Rollenzuweisung** - Benutzer erhalten Rollen nicht direkt,
> sondern über ihre Gruppenmitgliedschaft. Wenn ein neuer Benutzer im LDAP der
> Gruppe "entwicklung" hinzugefügt wird, erhält er nach der nächsten
> Synchronisation automatisch die Keycloak-Rolle "entwicklung".

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Den **LDAP-Verzeichnisdienst** mit Benutzern und Gruppen erkundet
- [x] **User Federation** mit OpenLDAP in Keycloak konfiguriert
- [x] LDAP-Benutzer nach Keycloak **synchronisiert** und Login getestet
- [x] Einen **Gruppen-Mapper** eingerichtet, der LDAP-Gruppen synchronisiert
- [x] LDAP-Gruppen auf **Keycloak Realm Roles** gemappt
