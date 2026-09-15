# LDAP: Vorhersagen und Gegenproben

## Übungsziel

Am Ende dieser Übung hast du:

- Erklärt, warum eine erfolgreiche LDAP-Suche trotzdem keinen Benutzer liefert
- Anna im LDAP einer weiteren Gruppe zugeordnet und ihre geerbten Keycloak-Rollen geprüft
- Die Gruppenänderung zurückgenommen und den Ausgangszustand wiederhergestellt

**Dauer:** 15 Minuten nach dem vollständigen Lab 07c, anschließend gemeinsame AD-Auswertung.
**Arbeitsform:** Zweiergruppen; eine Person bedient, die andere formuliert die Vorhersage.

## Voraussetzungen

Bearbeite zuerst [Lab 07c][lab], einschließlich Gruppen-Mapper und Zuordnung der Rollen.
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

Schaut euch den ersten Befehl an. Erwartet ihr einen Fehler, keinen Treffer oder einen Benutzer?
Führt ihn nach eurer Vorhersage in der passenden Shell aus.

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

Jetzt ändert sich nur die Suchbasis. Sagt das Ergebnis erneut voraus, bevor ihr den Befehl ausführt:

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

Testet die falsche Suchbasis nur mit `ldapsearch`. Wenn ihr `Users DN` im bestehenden
Keycloak-Provider ändert, betrifft das auch bereits importierte Benutzer und erschwert
den Vergleich der beiden Suchen.

## Teil 2: Anna erhält vorübergehend eine weitere Gruppe

Öffnet **Users → anna.schmidt → Role mapping** und zeigt auch die geerbten Rollen an.
Notiert, ob `entwicklung` bereits auftaucht. Lest dann die Datei
[anna-entwicklung-hinzufuegen.ldif](ldif/anna-entwicklung-hinzufuegen.ldif):
Welche einzelne Mitgliedschaft wird geändert?

Kopiert die Datei in euren OpenLDAP-Container und wendet sie an. Diese beiden Befehle
funktionieren in Bash und PowerShell:

```bash
docker cp workshops/ldap-ad/ldif/anna-entwicklung-hinzufuegen.ldif assignment-openldap:/tmp/anna-add.ldif
docker exec assignment-openldap ldapmodify -x -D "cn=admin,dc=mustertech,dc=de" -w admin -f /tmp/anna-add.ldif
```

Lest anschließend die Mitglieder der LDAP-Gruppe:

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

Ladet Annas Rollen in Keycloak neu. Ist `entwicklung` schon dabei? Haltet das Ergebnis
fest, bevor ihr etwas synchronisiert.

### Gruppen und Cache aktualisieren

1. **User federation → mustertech-ldap → Mappers → group-mapper** öffnen.
2. **Action → Sync LDAP groups to Keycloak** ausführen.

Leert anschließend den User Cache mit der Admin CLI in eurem Keycloak-Container:

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

Der erste Befehl meldet die CLI im Container an. Der zweite leert den User Cache des
Übungsrealms `mustertech`. Bei der späteren Rücknahme genügt der zweite Befehl, solange
die CLI-Anmeldung noch gültig ist.

Öffnet Anna erneut und prüft ihre geerbten Rollen.

Angenommen, Anna hat vor der Änderung ein Access Token erhalten: Welche Rolle steht darin
jetzt? Ist sie durch das Leeren des User Cache aus der Anwendung abgemeldet worden?

### Änderung zurücknehmen

Die Rücknahme entfernt nur Annas zusätzliche Mitgliedschaft. Hans bleibt in der Gruppe.

```bash
docker cp workshops/ldap-ad/ldif/anna-entwicklung-entfernen.ldif assignment-openldap:/tmp/anna-remove.ldif
docker exec assignment-openldap ldapmodify -x -D "cn=admin,dc=mustertech,dc=de" -w admin -f /tmp/anna-remove.ldif
```

Synchronisiert die Gruppen erneut, leert den User Cache und öffnet Annas Rollen.
Von den fachlichen Rollen darf sie jetzt nur noch `vertrieb` erben; technische Standardrollen
können zusätzlich auftauchen. Meldet LDAP beim Hinzufügen oder Entfernen einen Fehler,
lest zuerst die Gruppenmitglieder aus. Möglicherweise wurde die Änderung bereits ausgeführt.

## Teil 3: Transfer auf Active Directory

Besprecht anschließend, was sich bei einem Active Directory ändern würde:

- Das AD-Team verschiebt Hans in eine andere OU. Welche Identifikatoren und Suchgrenzen sind betroffen?
- Anna ist nur über eine verschachtelte AD-Gruppe berechtigt. Welche Mapper-Einstellung müsst ihr prüfen?
- Ein Konto wird im AD deaktiviert. Was prüft ihr getrennt für neuen Login, SSO, Refresh und vorhandenes Token?
- LDAP ist erreichbar, TLS schlägt fehl. Welche Nachweise braucht ihr vom AD- und Plattformteam?
- Der Windows-Desktop ist angemeldet. Reicht die LDAP-Anbindung für eine Anmeldung ohne Passwortdialog?

[lab]: ../../labs/assignments/modul-07c-ldap-federation/README.md
[wechsel]: ../../labs/assignments/TROUBLESHOOTING.md#container-name-konflikt
