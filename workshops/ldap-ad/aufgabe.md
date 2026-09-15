# LDAP: Vorhersagen und Gegenproben

## Übungsziel

Nach diesen Gegenproben hast du Suchfehler von Verbindungsfehlern unterschieden und eine
LDAP-Gruppenänderung bis zur geerbten Keycloak-Rolle verfolgt.

**Dauer:** 15 Minuten nach dem vollständigen Lab 07c, anschließend gemeinsame AD-Auswertung.
**Arbeitsform:** Zweiergruppen; eine Person bedient, die andere formuliert die Vorhersage.

## Voraussetzungen

Bearbeite zuerst [Lab 07c][lab]. Benutzer, Gruppen-Mapper und Rollen-Zuordnung müssen eingerichtet sein.
Anna gehört zunächst nur zur Gruppe `vertrieb`, Hans zur Gruppe `entwicklung`.
Alle folgenden Befehle werden im Kurs-Repository ausgeführt, in Bash oder PowerShell.
Die verwendeten Zugangsdaten gehören ausschließlich zur lokalen Übung.

Falls die Umgebung noch nicht läuft, beachte vor dem Start den
[Hinweis zum Wechsel zwischen Labs][wechsel] und starte sie:

```bash
docker compose -f labs/assignments/modul-07c-ldap-federation/docker-compose.yml up -d
docker compose -f labs/assignments/modul-07c-ldap-federation/docker-compose.yml ps -a
```

Keycloak, PostgreSQL und OpenLDAP müssen `healthy` sein; der Setup-Container endet mit
`Exited (0)`. Die laufenden Container einer anderen Übung nicht parallel verwenden.

## Teil 1: Verbindung erfolgreich, Benutzer fehlt

Sagt vor jedem Aufruf voraus: Fehler, kein Treffer oder ein Benutzer?
Verwende die passende Shell-Variante.

**Bash:**

```bash
docker exec assignment-openldap ldapsearch -x -LLL -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "ou=users,dc=mustertech,dc=de" -s one "(uid=hans.mueller)" dn
```

**PowerShell:**

```powershell
docker exec assignment-openldap ldapsearch -x -LLL -D "cn=admin,dc=mustertech,dc=de" -w admin `
  -b "ou=users,dc=mustertech,dc=de" -s one "(uid=hans.mueller)" dn
```

Wiederholt die Suche im vorhandenen Gruppen-Zweig:

**Bash:**

```bash
docker exec assignment-openldap ldapsearch -x -LLL -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "ou=groups,dc=mustertech,dc=de" -s one "(uid=hans.mueller)" dn
```

**PowerShell:**

```powershell
docker exec assignment-openldap ldapsearch -x -LLL -D "cn=admin,dc=mustertech,dc=de" -w admin `
  -b "ou=groups,dc=mustertech,dc=de" -s one "(uid=hans.mueller)" dn
```

Haltet fest:

1. Welche Einstellung blieb identisch, welche änderte sich?
2. Warum belegt ein erfolgreicher Bind noch nicht, dass Keycloak Hans findet?
3. Was würden `One Level` und `Subtree` bei Benutzern in untergeordneten OUs ändern?

Lasst die Keycloak-Konfiguration unverändert. Ein absichtlich falscher `Users DN` im
bestehenden Provider kann zusätzlich den Umgang mit bereits importierten Benutzern beeinflussen.

## Teil 2: Anna erhält vorübergehend eine weitere Gruppe

Prüft unter **Users → anna.schmidt → Role mapping** zunächst die geerbten Rollen.
Notiert, ob `entwicklung` bereits auftaucht. Dann untersucht die Datei
[anna-entwicklung-hinzufuegen.ldif](ldif/anna-entwicklung-hinzufuegen.ldif):
Welche einzelne Mitgliedschaft wird geändert?

Die Datei in den eigenen OpenLDAP-Container kopieren und anwenden:

```bash
docker cp workshops/ldap-ad/ldif/anna-entwicklung-hinzufuegen.ldif assignment-openldap:/tmp/anna-add.ldif
docker exec assignment-openldap ldapmodify -x -D "cn=admin,dc=mustertech,dc=de" -w admin -f /tmp/anna-add.ldif
```

Prüft den tatsächlichen LDAP-Zustand:

**Bash:**

```bash
docker exec assignment-openldap ldapsearch -x -LLL -D "cn=admin,dc=mustertech,dc=de" -w admin \
  -b "cn=entwicklung,ou=groups,dc=mustertech,dc=de" -s base "(objectClass=*)" member
```

**PowerShell:**

```powershell
docker exec assignment-openldap ldapsearch -x -LLL -D "cn=admin,dc=mustertech,dc=de" -w admin `
  -b "cn=entwicklung,ou=groups,dc=mustertech,dc=de" -s base "(objectClass=*)" member
```

Prüft Anna erneut in Keycloak. Notiert zuerst die Beobachtung, ohne sofort zu synchronisieren.
Führt dann die Schritte zur gezielten Aktualisierung aus:

1. **User federation → mustertech-ldap → Mappers → group-mapper** öffnen.
2. **Action → Sync LDAP groups to Keycloak** ausführen.
3. Den User Cache mit der Admin CLI im eigenen Keycloak-Container leeren:

**Bash:**

```bash
docker exec assignment-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master --user admin --password admin
docker exec assignment-keycloak /opt/keycloak/bin/kcadm.sh create clear-user-cache -r mustertech
```

**PowerShell:**

```powershell
docker exec assignment-keycloak /opt/keycloak/bin/kcadm.sh config credentials `
  --server http://localhost:8080 --realm master --user admin --password admin
docker exec assignment-keycloak /opt/keycloak/bin/kcadm.sh create clear-user-cache -r mustertech
```

Die CLI-Anmeldung gilt im Container für die folgenden Admin-Kommandos. Bei der Rücknahme
reicht das zweite Kommando, solange die Anmeldung noch gültig ist. Das Leeren betrifft
nur den User Cache des Übungsrealms `mustertech`.

4. Anna erneut öffnen und die geerbten Rollen prüfen.

Diskutiert: Warum ist eine Gruppenänderung im LDAP etwas anderes als die Rolle in einem
bereits ausgestellten Access Token? Weshalb ist Cache-Leeren noch kein Session-Logout?

### Änderung zurücknehmen

Die Rücknahme entfernt nur Annas zusätzliche Mitgliedschaft. Hans bleibt in der Gruppe.

```bash
docker cp workshops/ldap-ad/ldif/anna-entwicklung-entfernen.ldif assignment-openldap:/tmp/anna-remove.ldif
docker exec assignment-openldap ldapmodify -x -D "cn=admin,dc=mustertech,dc=de" -w admin -f /tmp/anna-remove.ldif
```

Wiederholt Gruppensynchronisation, Leeren des User Cache und Rollenprüfung. Kontrolliert,
dass Anna wieder nur die fachliche Rolle `vertrieb` erbt. Technische Standardrollen können
zusätzlich vorhanden sein. Ein erneutes Hinzufügen beziehungsweise Entfernen desselben
Werts kann einen LDAP-Fehler melden; prüft zuerst den Ist-Zustand statt weitere Werte zu ändern.

## Teil 3: Transfer auf Active Directory

Bereitet für die gemeinsame Auswertung Antworten auf diese Fälle vor:

- Das AD-Team verschiebt Hans in eine andere OU. Welche Identifikatoren und Suchgrenzen sind betroffen?
- Anna ist nur über eine verschachtelte AD-Gruppe berechtigt. Welche Mapper-Einstellung müsst ihr prüfen?
- Ein Konto wird im AD deaktiviert. Was prüft ihr getrennt für neuen Login, SSO, Refresh und vorhandenes Token?
- LDAP ist erreichbar, TLS schlägt fehl. Welche Nachweise braucht ihr vom AD- und Plattformteam?
- Der Windows-Desktop ist angemeldet. Reicht die LDAP-Anbindung für eine Anmeldung ohne Passwortdialog?

[lab]: ../../labs/assignments/modul-07c-ldap-federation/README.md
[wechsel]: ../../labs/assignments/TROUBLESHOOTING.md#container-name-konflikt
