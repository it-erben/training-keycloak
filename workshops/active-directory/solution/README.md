# Trainerlösung: LDAP-Provider per kcadm

`apply-solution.sh` legt den vollständigen LDAP-Provider für den eigenen DC an und schaltet die
Einstellungen um, die die Teilnehmer in den Aufgaben von Hand ändern. Das Skript läuft im
Keycloak-Container des lokalen Stacks; der Compose-Stack bindet dieses Verzeichnis unter
`/workshop/solution` und `lab/secrets/` unter `/workshop/secrets` ein.

## Voraussetzungen

- Laufender Stack aus `../lab` mit eingetragener `AD_PUBLIC_IP` und `certs/workshop-ca.crt`.
- Bind-Passwort in `lab/secrets/bind.pw`, angelegt mit
  `docker compose exec -it ldap-tools save-secret bind`.

## Aufruf

Aus `workshops/active-directory/lab`, Bash und PowerShell gleich:

```bash
docker compose exec keycloak bash /workshop/solution/apply-solution.sh <befehl>
```

| Befehl               | Wirkung                                                                          |
| -------------------- | -------------------------------------------------------------------------------- |
| `create`             | Provider `ad-team01` (READ_ONLY, LDAPS, `OU=Users`) und Group-Mapper `ad-groups` |
| `sync`               | Vollständiger Benutzer-Sync, danach Gruppen-Sync LDAP nach Keycloak              |
| `strategy direct`    | Gruppen nur aus dem `member`-Attribut (Ausgangszustand)                          |
| `strategy recursive` | `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY`, löst verschachtelte Gruppen auf   |
| `users-dn users`     | Users DN zurück auf `OU=Users,OU=Workshop,...`                                   |
| `users-dn workshop`  | Users DN auf `OU=Workshop`, findet auch `OU=Moved`                               |
| `logout-sessions`    | Beendet alle Sitzungen im Realm `mustertech`                                     |
| `status`             | Provider- und Mapper-Konfiguration, Keycloak-Gruppen von Hans und Anna           |
| `delete`             | Entfernt den Provider samt importierten Benutzern                                |

Der Ablauf des Workshops entspricht dieser Reihenfolge: `create`, `sync` (Aufgabe 2),
`strategy recursive`, `sync` (Aufgabe 3), `users-dn workshop`, `sync` (Aufgabe 4), nach jeder
AD-Änderung `sync` (Aufgabe 5), zum Schluss `users-dn users`, `sync`, `logout-sessions` (Aufgabe 6).

## Endzustand des Providers

| Feld                    | Wert                                                              |
| ----------------------- | ----------------------------------------------------------------- |
| Vendor                  | Active Directory                                                  |
| Connection URL          | `ldaps://dc01.ad.mustertech.test:636`                             |
| Use Truststore SPI      | Always                                                            |
| Bind type / Bind DN     | simple / `bind@ad.mustertech.test`                                |
| Edit mode               | READ_ONLY                                                         |
| Users DN                | `OU=Users,OU=Workshop,OU=Workshop,DC=ad,DC=mustertech,DC=test`    |
| Username LDAP attribute | `userPrincipalName`                                               |
| RDN LDAP attribute      | `cn`                                                              |
| UUID LDAP attribute     | `objectGUID`                                                      |
| User object classes     | `person, organizationalPerson, user`                              |
| User LDAP filter        | Oder-Filter auf `sAMAccountName` von Hans und Anna, siehe unten   |
| Search scope            | Subtree                                                           |
| Import users            | On                                                                |
| Sync Registrations      | Off                                                               |
| Periodic sync           | Aus (`-1`), Änderungen werden im Workshop von Hand synchronisiert |

Der Benutzerfilter lautet:

```text
(|(sAMAccountName=hans)(sAMAccountName=anna))
```

Group-Mapper `ad-groups`: Groups DN `OU=Groups,OU=Workshop,...`, Group Name LDAP Attribute `cn`,
Group Object Classes `group`, Membership LDAP Attribute `member`, Membership Attribute Type `DN`,
Membership User LDAP Attribute `cn`, Mode `READ_ONLY`, Groups Path `/`, Preserve Group Inheritance
`Off`, User Groups Retrieve Strategy zunächst `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE`.

Preserve Group Inheritance bleibt aus, damit `Manager` nicht als Untergruppe von `Teamleitung`
entsteht. Nur so unterscheidet sich die direkte von der rekursiven Auflösung sichtbar.

Der Provider legt beim Anlegen die Standard-Mapper für AD an: `username`, `first name`,
`last name`, `email`, `creation date`, `modify date` und `MSAD account controls`. Die
Rollenzuordnung kommt aus dem Realm-Import: Gruppe `Mitarbeiter` trägt `mitarbeiter`,
`Manager` trägt `manager`, `Teamleitung` trägt keine Rolle.
