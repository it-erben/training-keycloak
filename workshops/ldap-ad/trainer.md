# Trainerleitfaden: LDAP, AD und Keycloak

## Vorbereitung und Ziel

Die Gruppe verfolgt einen Login vom eingegebenen Benutzernamen bis zur Rolle in Keycloak.
Dabei soll sie erklären können, warum ein erreichbares LDAP noch keinen erfolgreichen
Login bedeutet und weshalb geänderte Rechte erst später in einer Anwendung ankommen können.
Plane 90 Minuten einschließlich Lab 07c ein. Die praktischen Versuche laufen in OpenLDAP;
für die AD-Fragen gibt es Musterantworten, aber keinen AD-Server im Lab.

Nutze die [Ablauftabelle](README.md#ablauf) und die [Vertiefungsfolien](slides.md).
Lass die Gruppe vor jedem Versuch das Ergebnis vorhersagen. Zeige bei Bedarf, wo sie
LDAP-Einträge oder geerbte Rollen findet. Die beiden LDIF-Dateien fügen Anna der Gruppe
`entwicklung` hinzu und nehmen diese Änderung anschließend zurück.

## Die ersten 15 Minuten: Ein Verzeichnis lesen

Ein LDAP-Verzeichnis besteht aus Einträgen mit Attributen. `objectClass` beschreibt,
welche Objektarten und Attribute ein Eintrag unterstützt. LDAP ist das Zugriffsprotokoll;
Active Directory Domain Services ist ein Verzeichnisdienst mit weiteren Diensten.

Am Baum aus Lab 07c zeigen:

- **DN:** `uid=hans.mueller,ou=users,dc=mustertech,dc=de` benennt den Eintrag im Baum.
- **RDN:** `uid=hans.mueller` ist der relative Name unter dem übergeordneten Eintrag.
- **Base DN:** `ou=users,dc=mustertech,dc=de` legt den Ausgangspunkt einer Suche fest.
- **Scope:** `base` prüft den Ausgangseintrag, `one` seine direkten Kinder, `sub` den gesamten Teilbaum.
- **Filter:** `(uid=hans.mueller)` schränkt die Treffer anhand von Attributen ein.

Wird Hans in eine andere OU verschoben oder umbenannt, kann sich sein DN ändern.
Keycloak soll ihn trotzdem als denselben Benutzer erkennen. Dafür verwendet der
LDAP-Provider im Lab `entryUUID`, bei AD üblicherweise `objectGUID`. Diese LDAP-ID ist
ein anderer Bezeichner als Keycloaks Benutzer-ID oder das OIDC-Subject.

Frage am Baum: "Findet ihr Hans auch, wenn ihr mit demselben Filter unter `ou=groups` sucht?"
Lass die Gruppe den Suchweg zeigen. Daran erkennst du, ob sie Basis, Scope und Filter auseinanderhält.

## Minute 15-30: Anmeldung Schritt für Schritt

Das [Diagramm](images/ldap-login.svg) zeigt einen Login mit Simple Bind wie im Lab.
Seine Pfeile erklären die Aufgaben der beteiligten Systeme. Ein Paketmitschnitt kann
anders aussehen, weil Keycloak Verbindungen wiederverwendet, Daten aus Caches liest
oder weitere Mapper-Abfragen ausführt. Eine bestehende SSO-Sitzung kann die Passwortprüfung überspringen.

1. Die Anwendung schickt den Browser im OIDC-Flow zu Keycloak. Bei erforderlicher
   Neuanmeldung nimmt Keycloak Benutzername und Passwort entgegen.
2. Für Verzeichniszugriffe meldet sich Keycloak mit dem technischen Bind-Konto am LDAP an.
   Dieses Konto braucht die für Suche und Mapping nötigen Rechte; produktiv kein Verzeichnis-Admin.
3. Keycloak sucht den Benutzer unter der konfigurierten Basis mit passenden Attributen und Filtern.
   Der gefundene DN bezeichnet den Benutzer für die Passwortprüfung.
4. Ein Bind als Benutzer mit dessen eingegebenem Passwort prüft die Anmeldedaten.
   Keycloak liest dafür nicht das gespeicherte LDAP-Passwort oder dessen Hash aus.
5. Der LDAP-Provider und seine Mapper liefern Attribute und Zugehörigkeiten. Keycloak führt
   gegebenenfalls weitere Schritte wie MFA aus und setzt den OIDC-Flow fort.
6. Im Authorization Code Flow erhält der Client zunächst einen Code und tauscht ihn am
   Token-Endpunkt ein. Die Anwendung benötigt dafür keinen eigenen LDAP-Zugang.

Lass nach Schritt 4 kurz erklären, wessen Passwort **Test authentication** prüft.
Die Schaltfläche testet die konfigurierten Bind-Zugangsdaten, im Lab also die des
technischen Kontos. Ob Hans sich anmelden kann, zeigt erst ein Login mit seinem Passwort.

### Was bleibt in LDAP, was liegt in Keycloak?

LDAP hält die Verzeichniseinträge. Wenn Keycloak einen Benutzer importiert, legt es einen
dauerhaften lokalen Datensatz an, der mit dem LDAP-Provider verknüpft bleibt und später
durch den zusätzlichen User Cache zwischengespeichert werden kann. Import und Cache erfüllen
also unterschiedliche Aufgaben.

Im READ_ONLY-Lab prüft LDAP weiterhin das Passwort. Der Import übernimmt dieses Passwort
nicht und eignet sich deshalb auch nicht als vollständiges Verzeichnisbackup. Im Modus
UNSYNCED lassen sich dagegen bewusst lokale Passwörter in Keycloak setzen. Und wer schon
eine gültige SSO-Sitzung besitzt, braucht beim nächsten Anwendungsaufruf möglicherweise
gar keine erneute Passwortprüfung.

### Edit Mode, Import und Mapper

- **READ_ONLY:** LDAP-verwaltete Daten werden über diesen Provider nicht zurückgeschrieben.
  Der LDAP-Server braucht trotzdem passende ACLs: Das Admin-Konto aus dem Lab besitzt dort weiterhin Schreibrechte.
- **WRITABLE:** Unterstützte Änderungen können ins LDAP gehen. Rechte, Schema, Mapper,
  Passwortverfahren und TLS müssen dazu passen.
- **UNSYNCED:** Änderungen können lokal bleiben, einschließlich lokal gesetzter Passwörter.
  Das bedeutet nicht, dass jede LDAP-Verbindung oder jede Mapper-Abfrage abgeschaltet wird.

Wo Keycloak Attribute liest und speichert, hängt außerdem von `Import Users` und den
Mappern ab. Beim Anlegen des Providers bestimmen Vendor, Import und Edit Mode, welche
Mapper automatisch entstehen. Wer den Modus später ändert, muss die vorhandenen Mapper
einzeln prüfen; sie werden dabei nicht automatisch passend umgebaut.

Keycloak bietet getrennte Synchronisationen für alle Benutzer, geänderte Benutzer und
Gruppen. Wenn Anna einer Gruppe hinzugefügt wird, kann sich nur deren Gruppeneintrag
ändern. Eine Suche nach geänderten Benutzereinträgen muss das dann nicht erfassen.
Darum reicht "Changed users sync" nicht für jede Änderung an Gruppenrechten.

## Minute 30-60: Die Teilnehmer bearbeiten 07c

Starte mit der Umgebung und der Realm-Datei aus Lab 07c. Lass die Gruppe zunächst
DN, `uid`, `givenName` und `member` in der LDAP-Ausgabe finden.

Am Ende sollen drei Nachweise vorliegen:

1. Anmeldung als LDAP-Benutzer im privaten Browserfenster funktioniert.
2. Der Vorname ist richtig zugeordnet, der Federation Link zeigt den Provider.
3. Anna erbt `vertrieb`, Hans `entwicklung`; die Gruppen existieren in beiden Systemen.

Bestehe beim Login-Test auf einem privaten Browserfenster ohne vorhandene SSO-Sitzung.
Sonst könnte die Anmeldung funktionieren, obwohl Keycloak das LDAP-Passwort gar nicht geprüft hat.

## Minute 60-75: Musterlösungen der Gegenproben

### A: Erfolgreiche Suche ohne Treffer

Die erste Suche findet Hans. Die zweite läuft erfolgreich durch, findet aber unter
`ou=groups` keinen passenden Benutzer. Server, Bind DN, Passwort und Filter blieben gleich.
Der Exit-Code einer erfolgreichen LDAP-Suche kann auch bei null Treffern null sein.

Ein nicht existierender Base DN wäre ein anderer Fall: Hier kann LDAP `No such object`
liefern. Ein falsches Bind-Passwort wiederum verhindert bereits die authentifizierte Suche.
Die Aufgabe wählt bewusst einen vorhandenen, fachlich unpassenden Zweig.

Bei Benutzern in tieferen OUs reicht `One Level` nicht. `Subtree` sucht tiefer, kann aber
bei zu breiter Basis auch unerwünschte Konten einschließen. Basis und Filter müssen den
vorgesehenen Benutzerkreis gemeinsam begrenzen.

### B: Gruppenänderung und Rechte

Die LDIF-Datei fügt Anna als zweiten `member` zur Gruppe `entwicklung` hinzu. Hans bleibt
Mitglied; Annas Mitgliedschaft in `vertrieb` wird nicht verändert.

Erwartung nach gezielter Gruppensynchronisation, Leeren des User Cache und erneutem Laden:
Anna erbt zusätzlich `entwicklung`. Nach der Rücknahme und denselben Aktualisierungsschritten
verschwindet diese Rolle wieder; `vertrieb` bleibt.

Vor der Synchronisation kann die Rolle bereits sichtbar sein oder noch fehlen. Obwohl der
Gruppen-Mapper Mitgliedschaften beim Laden des Benutzers abfragen kann, liefert ein
vorhandener Cache-Eintrag möglicherweise noch den alten Stand. Lass beide Beobachtungen
gelten und frage nach, wann und wo die Gruppe nachgesehen hat.

Die Aufgabe synchronisiert anschließend die Gruppen und leert den User Cache, damit
die Rollenprüfung mit neu geladenen Daten erfolgt. Wie lange das im Produktivbetrieb
ohne diesen Eingriff dauert, muss das Betriebsteam gesondert messen und begrenzen.

Ein schon ausgestelltes JWT behält seine Claims. Die API kann es bis zu seiner
Gültigkeitsgrenze akzeptieren, wenn sie keine zusätzlichen aktuellen Rechte abfragt.
Auch die Anwendungssitzung bleibt beim Cache-Leeren bestehen. Lass die Gruppe deshalb
neuen Login, Refresh und API-Zugriff auseinanderhalten; bei Anwendungen mit Introspection
gehört deren Verhalten ebenfalls in den Test.

## Minute 75-90: Active Directory und Betrieb

### AD DS, Entra ID und Kerberos

Kläre zuerst, was mit "unser AD" gemeint ist. AD DS bietet LDAP und Kerberos. Entra ID
lässt sich über OIDC oder SAML als externer Identity Provider anbinden; das wäre Identity
Brokering. Microsoft Entra Domain Services stellt wiederum verwaltete Domänendienste bereit.
Je nach gewähltem Weg ändern sich der Login-Ablauf und die Stelle, die MFA durchsetzt.

Für Windows-SSO kann Keycloak Kerberos/SPNEGO verwenden. Dafür braucht es unter anderem
passende DNS-Namen, Zeitsynchronisation, Service Principal und Keytab sowie eine geeignete
Browserkonfiguration. LDAP-Federation allein richtet das nicht ein. Die LDAP-Benutzerquelle
und der Kerberos-Anmeldeweg können sich ergänzen.

### Welche Werte werden bei AD anders?

| Zweck                | OpenLDAP-Lab             | AD-Transfer                                                       |
| -------------------- | ------------------------ | ----------------------------------------------------------------- |
| Login-Attribut       | `uid`                    | `sAMAccountName` oder bewusst gewählter UPN                       |
| Objektidentifikation | `entryUUID`              | `objectGUID`                                                      |
| Benutzerklasse       | `inetOrgPerson`          | AD-Schema, etwa `user`                                            |
| Benennung im Baum    | RDN mit `uid`            | Häufig RDN mit `cn`; nicht mit Login verwechseln                  |
| Gruppen              | `groupOfNames`, `member` | AD-Gruppen; direkte und verschachtelte Mitgliedschaft prüfen      |
| Kontozustand         | Einfacher Lab-Fall       | MSAD User Account Mapper, etwa `userAccountControl`, `pwdLastSet` |

Der UPN muss nicht gleich der Mail-Adresse sein. Ein `sAMAccountName` reicht bei mehreren
Domänen nicht als organisationsweit eindeutige Identität. Bei mehreren Verzeichnissen
müssen Namenskollisionen und Kontenzuordnung vor einer gemeinsamen Realm-Anbindung geklärt werden.

### Antworten auf die Transferfragen

- **OU-Wechsel:** DN und Suchbereich prüfen. `objectGUID` bleibt für dasselbe AD-Objekt
  erhalten; ein gelöschtes und neu angelegtes Konto ist ein neues Objekt. Ein Benutzer außerhalb
  der Suchbasis wird nicht dadurch auffindbar, dass seine ID stabil ist.
- **Verschachtelte Gruppe:** Direkte Mitgliedschaft und transitive Auflösung unterscheiden.
  Eine passende rekursive Retrieve Strategy beziehungsweise Gruppenhierarchie prüfen. Insbesondere
  nicht voraussetzen, dass jedes `memberOf`-Ergebnis bereits alle indirekten Gruppen enthält.
- **Deaktiviertes Konto:** MSAD-Mapper und Cache-Verhalten prüfen, frischen Login versuchen.
  Bestehende Keycloak- und App-Sitzungen, Refresh sowie noch gültige Tokens separat testen.
  Eine Kontosperre im AD ist keine pauschale Sofort-Sperre aller bereits aktiven Anwendungen.
- **TLS-Fehler:** Servername/SAN, Zertifikatskette, Gültigkeit, Truststore und gewählten TLS-Modus
  prüfen. LDAPS startet mit TLS; StartTLS schützt eine LDAP-Verbindung nach dem Upgrade.
  Port 389 bedeutet deshalb nicht automatisch Klartext. TLS schützt Client-zu-Keycloak und
  Keycloak-zu-LDAP jeweils getrennt; Zertifikatsprüfung nicht zur Fehlerbehebung abschalten.
- **Windows-Desktop angemeldet:** Für Kerberos/SPNEGO ist zusätzliche Konfiguration nötig.
  Eine LDAP-Passwortprüfung übernimmt nicht automatisch die Windows-Anmeldung.

### Abnahmefragen für eine reale AD-Anbindung

Das AD-Team liefert Suchbereiche, Schema, Kontozustände und Testkonten mit direkter sowie
verschachtelter Mitgliedschaft. Das Plattformteam bestätigt TLS, DNS, Erreichbarkeit und
Rechte des technischen Kontos. Das Anwendungsteam prüft Rollen und Sperrwirkung bis zur API.

Mindestens testen: normaler Login, falsches Passwort, gesperrtes Konto, abgelaufenes Passwort,
OU-Wechsel, Gruppenentzug, LDAP-Ausfall und Wiederkehr. Für jeden Test Zeitpunkt, neuen Login,
bestehende Sitzung und Token-Verwendung getrennt protokollieren. Bei mehreren LDAP-Endpunkten
zusätzlich Replikationsstand, Identifikatoren und Failover prüfen.

## Quellen und Grenzen

Die Erklärungen zu LDAP-Modi und Mappern beziehen sich auf Keycloak 26.5.0. Kerberos-SSO,
AD-Kontosperren und TLS müssen später in der tatsächlichen AD-Umgebung geprüft werden;
die OpenLDAP-Versuche decken diese Funktionen nicht ab.

- [LDAP-Federation und Mapper, Keycloak 26.5.0][ldap]
- [Keycloak: Kerberos][kerberos]
- [Microsoft: AD DS und Entra ID vergleichen][compare]
- [Microsoft: objectGUID][guid]
- [Microsoft: sAMAccountName][sam]

[ldap]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/server_admin/topics/user-federation/ldap.adoc
[kerberos]: https://www.keycloak.org/docs/latest/server_admin/index.html#_kerberos
[compare]: https://learn.microsoft.com/en-us/entra/fundamentals/compare
[guid]: https://learn.microsoft.com/en-us/windows/win32/adschema/a-objectguid
[sam]: https://learn.microsoft.com/en-us/windows/win32/adschema/a-samaccountname
