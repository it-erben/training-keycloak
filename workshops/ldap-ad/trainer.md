# Trainerleitfaden: LDAP, AD und Keycloak

## Vorbereitung und Ziel

Die Gruppe soll einen LDAP-Login erklären, fehlerhafte Suchen erkennen und Änderungen
an Identitäten von deren Wirkung auf Anwendungen unterscheiden. Der Schwerpunkt braucht
90 Minuten einschließlich des bestehenden Labs. Eine produktive AD-Anbindung lässt sich
mit OpenLDAP allein nicht abnehmen.

Nutze die [Ablauftabelle](README.md#ablauf) und die [Vertiefungsfolien](slides.md).
Zeige vor der Arbeitsphase nur das Vorgehen zur Beobachtung, nicht beide Lösungen.
Für die Gegenproben stehen zwei LDIF-Dateien bereit. Sie ändern ausschließlich Annas
Mitgliedschaft in `entwicklung`; die zweite Datei stellt den Ausgangszustand wieder her.

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

Ein DN ist kein dauerhaft unveränderlicher Personenbezeichner. Eine Verschiebung oder
Umbenennung kann ihn ändern. Für die Wiedererkennung verwendet der LDAP-Provider im Lab
`entryUUID`; für AD ist `objectGUID` ein typischer Identifikator. Die LDAP-ID ist von
Keycloaks Benutzer-ID und dem OIDC-Subject zu unterscheiden.

Frage: "Unter welcher Suchbasis findet ihr Hans, und würde dieselbe Suche in `ou=groups`
funktionieren?" Die Antwort muss Suchbasis, Scope und Filter auseinanderhalten.

## Minute 15-30: Anmeldung Schritt für Schritt

Das [Diagramm](images/ldap-login.svg) zeigt den Simple-Bind-Fall des Labs. Es stellt
logische Operationen dar, keine Zusage über Anzahl, Wiederverwendung oder Reihenfolge aller
Netzwerkverbindungen. Caches, Mapper und bereits vorhandene Sitzungen verändern den Ablauf.

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

Frage: "Wessen Passwort prüft Test authentication in der Provider-Konfiguration?"
Antwort: die konfigurierten Bind-Zugangsdaten. Damit ist noch kein Benutzerlogin geprüft.

### Drei Zustände auseinanderhalten

**LDAP-Daten** sind der Verzeichnisbestand. **Importierte Benutzer** sind dauerhafte lokale
Datensätze mit Verknüpfung zum LDAP-Provider. Der **User Cache** ist zusätzlich ein Cache.
Ein lokaler Benutzerimport ist deshalb weder ein vollständiges Verzeichnisbackup noch ein
Beleg dafür, dass LDAP bei einer Passwortanmeldung nicht mehr benötigt wird.

Im READ_ONLY-Lab prüft LDAP das Passwort; der Import kopiert kein LDAP-Passwort nach Keycloak.
Von dieser Aussage sind bewusst in Keycloak gesetzte lokale Passwörter im UNSYNCED-Modus
zu unterscheiden. Nicht pauschal versprechen, jeder denkbare Login benötige immer LDAP:
Eine bereits bestehende SSO-Sitzung kann die erneute Passwortprüfung vermeiden.

### Edit Mode, Import und Mapper

- **READ_ONLY:** LDAP-verwaltete Daten werden über diesen Provider nicht zurückgeschrieben.
  Die Beschränkung ersetzt keine LDAP-ACL. Der im Lab verwendete LDAP-Admin bleibt technisch mächtig.
- **WRITABLE:** Unterstützte Änderungen können ins LDAP gehen. Rechte, Schema, Mapper,
  Passwortverfahren und TLS müssen dazu passen.
- **UNSYNCED:** Änderungen können lokal bleiben, einschließlich lokal gesetzter Passwörter.
  Das bedeutet nicht, dass jede LDAP-Verbindung oder jede Mapper-Abfrage abgeschaltet wird.

`Import Users` und die Mapper bestimmen zusätzlich, wo Attribute gelesen beziehungsweise
gehalten werden. Vendor, Import und Edit Mode beeinflussen die automatisch angelegten
Mapper. Ein späterer Moduswechsel baut diese nicht verlässlich passend um.

Vollständige Benutzersynchronisation, Synchronisation geänderter Benutzer und
Gruppensynchronisation sind zu unterscheiden. Eine Mitgliedschaft kann am Gruppeneintrag
geändert worden sein, ohne dass der Benutzereintrag dieselbe Änderung signalisiert.
"Changed users sync" deshalb nicht als universelle Aktualisierung aller Rechte erklären.

## Minute 30-60: Die Teilnehmer bearbeiten 07c

Der vorhandene Code und die Realm-Datei bleiben die Grundlage. Lass die Gruppe zuerst
selbst DN, `uid`, `givenName` und `member` in der LDAP-Ausgabe finden.

Am Ende sollen drei Nachweise vorliegen:

1. Anmeldung als LDAP-Benutzer im privaten Browserfenster funktioniert.
2. Der Vorname ist richtig zugeordnet, der Federation Link zeigt den Provider.
3. Anna erbt `vertrieb`, Hans `entwicklung`; die Gruppen existieren in beiden Systemen.

Ein Benutzer in der Admin-Konsole beweist allein noch keinen funktionierenden Login.
Ein normaler Browser mit gültiger SSO-Sitzung eignet sich nicht als Nachweis einer frischen Passwortprüfung.

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

Die Beobachtung vor dem expliziten Aktualisieren darf unterschiedlich ausfallen. Der
Gruppen-Mapper kann Mitgliedschaften beim Laden eines Benutzers ermitteln; zugleich kann
bereits ein User-Cache-Eintrag existieren. Eine sofort sichtbare Änderung ist deshalb kein
Fehler und kein Beleg für ständig sofortige Konsistenz. Notieren lassen, welche Abfrage
und welcher Zustand beobachtet wurden.

Der kontrollierte Ablauf synchronisiert Gruppen und leert den Cache, um eine alte lokale
Sicht auszuschließen. Er misst keine Garantie für die produktive Aktualisierungsdauer.
Im Betrieb braucht es dafür eine festgelegte Strategie mit überprüften Zeitgrenzen.

**Token-Bezug:** Ein bereits ausgestelltes signiertes JWT wird durch die Gruppenänderung
nicht nachträglich umgeschrieben. Die API kann es bis zur vorgesehenen Gültigkeitsgrenze
akzeptieren, sofern sie keine zusätzliche aktuelle Berechtigungsprüfung vornimmt.
Cache-Leeren beendet auch keine Anwendungssitzung. Neuen Login, Refresh, Introspection
und API-Autorisierung deshalb jeweils in der konkreten Anwendung testen.

## Minute 75-90: Active Directory und Betrieb

### AD DS, Entra ID und Kerberos

AD DS bietet unter anderem LDAP und Kerberos. Entra ID ist ein anderer Identitätsdienst;
eine OIDC-/SAML-Anbindung daran ist Identity Brokering. Entra Domain Services ist wiederum
von Entra ID zu unterscheiden. Ein Wechsel zwischen diesen Wegen verändert auch den
Anmeldeablauf und die Verantwortung für MFA.

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

Die konkreten LDAP-Modi und Mapper sind gegen die Dokumentation von Keycloak 26.5.0 eingeordnet.
AD- und TLS-Transferfragen brauchen eine Abnahme an der tatsächlichen Installation.
Das Lab weist weder Kerberos-SSO noch produktives AD-Lockout-Verhalten nach.

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
