---
marp: true
theme: default
paginate: true
header: "Modul 07: LDAP- und AD-Vertiefung"
footer: "CC BY-NC-SA 4.0, Alexander Erben"
---

# Modul 07: Vertiefung

## LDAP, Active Directory und Keycloak

Vom Verzeichnis zum Login und zur Berechtigung · 90 Minuten

---

## Lernziele

Nach diesem Modul kannst du:

- **LDAP-Suchen** anhand von Basis, Scope und Filter erklären.
- **Bind-Konto und Benutzerlogin** auseinanderhalten.
- Erklären, wann eine Gruppenänderung in **Keycloak und Tokens** sichtbar wird.
- Benennen, was bei der Anbindung von **Active Directory** zusätzlich zu prüfen ist.

---

## 1. Ein Verzeichnis lesen

LDAP ist ein Protokoll zum Abfragen und Verwalten von Verzeichniseinträgen.

```text
dc=mustertech,dc=de
├── ou=users
│   ├── uid=hans.mueller
│   └── uid=anna.schmidt
└── ou=groups
    ├── cn=entwicklung
    └── cn=vertrieb
```

**Eintrag:** Attribute wie `uid`, `mail`, `givenName` und `objectClass`.
**Gruppe im Lab:** `member` enthält den vollständigen DN des Mitglieds.

---

## 1.1 Name, Suchbasis und stabile ID

| Begriff         | Beispiel / Bedeutung                                    |
| --------------- | ------------------------------------------------------- |
| DN              | `uid=hans.mueller,ou=users,dc=mustertech,dc=de`         |
| RDN             | `uid=hans.mueller`, relativ zum übergeordneten Eintrag  |
| Base DN         | `ou=users,dc=mustertech,dc=de`, Ausgangspunkt der Suche |
| Stabile LDAP-ID | Im Lab `entryUUID`, bei AD typischerweise `objectGUID`  |

Beim Verschieben kann sich der DN ändern. Die ID desselben Objekts bleibt erhalten.
LDAP-ID, Keycloak-Benutzer-ID und OIDC-Subject sind unterschiedliche Bezeichner.

---

## 1.2 Wo und wonach sucht Keycloak?

- **Basis:** Unter welchem Eintrag beginnt die Suche?
- **Scope:** Nur dieser Eintrag, direkte Kinder oder der ganze Teilbaum?
- **Filter:** Welche Attribute müssen passen, etwa `(uid=hans.mueller)`?

Was findet dieser Filter unter `ou=groups`? Sagt das Ergebnis voraus.

Ein erfolgreicher LDAP-Aufruf kann null Treffer liefern.

---

## 2. Zwei verschiedene Anmeldungen am LDAP

Ein Bind authentifiziert eine Verbindung gegenüber dem LDAP-Server.

| Identität              | Zweck                                           |
| ---------------------- | ----------------------------------------------- |
| Technisches Bind-Konto | Benutzer und benötigte Attribute suchen / lesen |
| Gefundener Benutzer    | Sein eingegebenes Passwort per Bind überprüfen  |

**Test authentication** prüft die konfigurierten Bind-Zugangsdaten.
Ein erfolgreicher Test belegt noch keinen erfolgreichen Benutzerlogin.

---

![bg width:1150](images/ldap-login.svg)

---

## 2.1 Wo liegen Benutzerdaten und Rechte?

- **LDAP:** Benutzer, Passwortprüfung und LDAP-verwaltete Zugehörigkeiten
- **Lokaler Import:** Dauerhafte Benutzerdaten mit Verknüpfung zum LDAP-Provider
- **User Cache:** Bereits gelesene Daten, die Keycloak wiederverwendet
- **Access Token:** Bereits ausgestellte Claims ändern sich nicht nachträglich

Im READ_ONLY-Lab werden LDAP-Passwörter nicht nach Keycloak kopiert.
Eine bestehende SSO-Sitzung kann eine erneute Passwortprüfung vermeiden.

---

## 2.2 Wer darf Daten verändern?

| Edit Mode | Bedeutung                                                       |
| --------- | --------------------------------------------------------------- |
| READ_ONLY | Über diesen Provider keine Änderungen an LDAP-verwalteten Daten |
| WRITABLE  | Unterstützte Änderungen können ins LDAP geschrieben werden      |
| UNSYNCED  | Änderungen können lokal bleiben, auch lokal gesetzte Passwörter |

Auch Import Users, Attribut-Mapper und die Rechte im LDAP bestimmen das Verhalten.
Ein späterer Moduswechsel baut vorhandene Mapper nicht automatisch passend um.

---

## 3. Selbst bearbeiten: Lab 07c · 30 Minuten

1. Verzeichnis lesen und Benutzerquelle anbinden.
2. Benutzer importieren und einen frischen Login testen.
3. Gruppen-Mapper einrichten und Gruppen auf Rollen abbilden.

Prüft den Vornamen, den Federation Link und die geerbte Rolle.

Eine Person erklärt jeweils, was der nächste Klick bewirken soll.

---

## 3.1 Gegenproben · 15 Minuten

Sucht Hans zuerst unter `ou=users`, dann unter `ou=groups`.
Bind und Filter bleiben gleich. Sagt vor beiden Aufrufen das Ergebnis voraus.

Fügt Anna vorübergehend der Gruppe `entwicklung` hinzu.
Prüft die Änderung in LDAP und Keycloak, synchronisiert und nehmt sie wieder zurück.

Was geschieht dabei mit einem bereits ausgestellten Token?

---

## 4. Welches Microsoft-System ist gemeint?

| System / Verfahren               | Einordnung                                             |
| -------------------------------- | ------------------------------------------------------ |
| Active Directory Domain Services | Verzeichnisdienst, unter anderem LDAP und Kerberos     |
| Microsoft Entra ID               | Cloud-Identitätsdienst, etwa über OIDC/SAML angebunden |
| Microsoft Entra Domain Services  | Verwaltete Domänendienste; von Entra ID unterscheiden  |

**Entscheidung:** Benutzerquelle direkt anbinden oder einem externen IdP vertrauen?

---

## 4.1 Diese AD-Einstellungen braucht Keycloak

- **Login:** `sAMAccountName` oder `userPrincipalName`, passend zum Anmeldekonzept
- **Objekt-ID:** `objectGUID`; ein DN oder eine E-Mail ist kein Ersatz
- **Gruppen:** Direkte und verschachtelte Mitgliedschaft unterscheiden
- **Kontozustand:** MSAD User Account Mapper und Passwortzustände prüfen

Ein UPN muss nicht der Mail-Adresse entsprechen.
Bei mehreren Domänen muss die Kontozuordnung eindeutig bleiben.

---

## 4.2 Eine Sperre wirkt auf mehreren Ebenen

Anna verliert eine AD-Gruppe oder ihr Konto wird deaktiviert.

1. Ist die Änderung im verwendeten Verzeichnis sichtbar?
2. Wann laden Keycloak und seine Mapper den neuen Zustand?
3. Was passiert bei neuem Login, bestehendem SSO und Refresh?
4. Was akzeptiert die API mit einem vorhandenen Token noch?

Legt fest, wie schnell ein Rechteentzug wirken muss, und testet diese Frist bis zur API.

---

## 4.3 TLS und Betriebszugang

- **LDAPS:** TLS ab Verbindungsbeginn, typischerweise Port `636`
- **StartTLS:** Upgrade einer LDAP-Verbindung, typischerweise auf Port `389`
- **Vertrauen:** Zertifikatskette, Servername, Gültigkeit und Truststore prüfen
- **Bind-Konto:** Nur die benötigten Rechte, getrennt von der Benutzerprüfung

Im lokalen Lab nutzen wir vereinfachte Zugänge.
READ_ONLY in Keycloak ersetzt keine Berechtigungsbegrenzung im LDAP.

---

## 4.4 Windows-SSO ist ein eigener Anmeldeweg

Kerberos/SPNEGO kann eine vorhandene Windows-Anmeldung für Keycloak nutzbar machen.

- **Dienstidentität:** Service Principal und Keytab
- **Umgebung:** Passendes DNS und abgestimmte Zeit
- **Browser:** Kerberos-Nutzung für den Dienst zulassen
- **Keycloak:** Kerberos-Anmeldung und Benutzerzuordnung konfigurieren

LDAP-Federation allein aktiviert diesen Ablauf nicht.

---

## 4.5 Zurück zu Hans und Anna

- Warum kann Test authentication erfolgreich sein und Hans trotzdem nicht einloggen?
- Was ändert ein OU-Wechsel an Suche und Identität?
- Welche Wirkung hat Gruppenentzug auf ein vorhandenes JWT?
- Welche Einstellung fehlt für verschachtelte Gruppen möglicherweise?
- Warum reicht LDAP-Anbindung nicht für Windows-SSO?

Welche dieser Antworten könnt ihr im OpenLDAP-Lab prüfen, für welche braucht ihr ein AD?

---

## Quellen

- [LDAP-Federation und Mapper, Keycloak 26.5.0][ldap]
- [Keycloak: Kerberos][kerberos]
- [Microsoft: AD DS und Entra ID][compare]
- [Microsoft: objectGUID][guid]

Der Trainerleitfaden enthält Musterantworten und Hinweise zur produktiven Abnahme.

[ldap]: https://github.com/keycloak/keycloak/blob/26.5.0/docs/documentation/server_admin/topics/user-federation/ldap.adoc
[kerberos]: https://www.keycloak.org/docs/latest/server_admin/index.html#_kerberos
[compare]: https://learn.microsoft.com/en-us/entra/fundamentals/compare
[guid]: https://learn.microsoft.com/en-us/windows/win32/adschema/a-objectguid
