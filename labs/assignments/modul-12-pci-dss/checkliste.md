# Audit-Checkliste: Keycloak gegen PCI DSS v4.0.1

Trage in Teil 1 die Ist-Werte ein, nach jedem weiteren Teil den neuen Stand. Die Spalte
„Außerhalb von Keycloak" nennt, was die Organisation zusätzlich regeln muss.

| Anforderung | Soll | Keycloak-Einstellung | Ist vorher | Ist nachher | Außerhalb von Keycloak |
| --- | --- | --- | --- | --- | --- |
| 8.2.1 | Eindeutige Benutzerkennung pro Person | Users, keine Sammelkonten | | | Prozess bei Eintritt |
| 8.2.5 | Zugang bei Austritt sofort entzogen | User `Enabled` = Off, Sessions beendet | | | Offboarding-Prozess |
| 8.2.6 | Inaktiv nach 90 Tagen deaktiviert | Workflow `disable-user` (Bonus) | | | Ohne Workflow: Skript |
| 8.2.8 | Re-Authentifizierung nach 15 Minuten Inaktivität | Sessions: SSO Session Idle | | | Timeout in der Anwendung |
| 8.3.4 | Sperre nach ≤10 Fehlversuchen, ≥30 Minuten oder bis Admin-Freigabe | Brute force detection | | | |
| 8.3.5 | Erstpasswort einmalig, Wechsel beim ersten Login | Credentials: Temporary | | | Übergabe des Erstpassworts |
| 8.3.6 | ≥12 Zeichen, Buchstaben und Ziffern | Password policy: Minimum length, Digits, Upper/Lower case | | | |
| 8.3.7 | Keines der letzten 4 Passwörter | Password policy: Not recently used | | | |
| 8.3.9 | Wechsel alle 90 Tage, falls einziger Faktor | Password policy: Expire password | | | Entfällt bei MFA |
| 8.4.1 | MFA für jeden Admin-Zugang | Realm `master`: OTP Form Required | | | |
| 8.4.2 | MFA für jeden Zugang zur CDE | Realm `mustertech`: OTP Form Required | | | Welche Clients sind CDE? |
| 8.5.1 | MFA nicht umgehbar, replay-resistent | OTP Policy: Look ahead 1, Code nicht wiederverwendbar | | | |
| 8.6.1 | System-Accounts ohne interaktiven Login | Service Accounts: `Direct access grants` Off | | | |
| 8.6.3 | Secrets rotiert, nicht im Code | Client Policy `secret-rotation` | | | Secret-Ablage (Vault) |
| 7.2.1 | Zugriff nach Rolle, Least Privilege | Admin Permissions statt `realm-admin` | | | Rollenkonzept |
| 10.2.1 | Logins, Admin-Aktionen, Fehlversuche, Credential-Änderungen | Events, Admin events mit Representation | | | |
| 10.2.2 | Wer, Was, Wann, Erfolg, Herkunft, Ziel | `userId`, `type`, `time`, `error`, `ipAddress`, `clientId` | | | |
| 10.5.1 | 12 Monate, davon 3 sofort verfügbar | Expiration 90 Tage, `jboss-logging` nach stdout | | | Log-System |
| 10.6 | Zeitsynchronisation | | | | NTP auf den Hosts |
| 2.2.2 | Keine Standard-Zugangsdaten | Kein `admin/admin`, temporärer Bootstrap-Admin ersetzt | | | |
| 4.2.1 | Starke Verschlüsselung in Transit | `sslRequired: all`, TLS ≥1.2, HSTS am Proxy | | | Zertifikate, Proxy |
| 6.3.3 | Sicherheits-Patches innerhalb eines Monats | Keycloak-Version | | | Patch-Prozess |
