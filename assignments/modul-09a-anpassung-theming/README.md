# Modul 09a: Anpassung -- Theming

## Übungsziel

Am Ende dieser Übung hast du:

- Ein eigenes Theme für die Login-Seite erstellt
- Farben und Logo der Mustertech GmbH eingebunden
- Das Theme in Keycloak aktiviert
- E-Mail-Templates angepasst

**Geschätzte Dauer:** 20 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet
- Grundkenntnisse CSS

### Umgebung starten

```bash
cd assignments/modul-09a-anpassung-theming
docker compose up -d
```

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe diese zuerst
> mit `docker compose down -v` im Verzeichnis der vorherigen Übung. Details siehe
> [Troubleshooting](#container-name-konflikt).

Warte bis Keycloak, Portal-Frontend und Mailpit bereit sind (~60 Sekunden). Der Realm
"mustertech" wird automatisch importiert mit allen Clients und Authorization Services aus den
vorherigen Modulen.

---

## Teil 1: Theme-Struktur verstehen

### Schritt 1.1: Theme-Typen

Keycloak unterstützt verschiedene Theme-Typen:

| Typ       | Zweck                                      |
|:----------|:-------------------------------------------|
| `login`   | Login-Seite, Registrierung, Passwort-Reset |
| `account` | Account Console (Self-Service)             |
| `admin`   | Admin Console                              |
| `email`   | E-Mail-Templates                           |
| `common`  | Gemeinsame Ressourcen                      |

### Schritt 1.2: Theme-Vererbung

Themes können von anderen Themes erben:

- `base` -> Grundlegende Templates
- `keycloak` -> Älteres Standard-Theme (PatternFly 3/4)
- `keycloak.v2` -> Neues Standard-Theme ab Keycloak 26 (PatternFly v5)
- `mustertech` -> Unser Custom Theme (erbt von `keycloak.v2`)

---

## Teil 2: Code-Walkthrough -- Theme-Verzeichnisstruktur

Das fertige Theme liegt unter `../services/keycloak/themes/mustertech/` und hat folgenden Aufbau:

```
../services/keycloak/themes/mustertech/
├── login/
│   ├── theme.properties
│   ├── resources/
│   │   ├── css/
│   │   │   └── mustertech.css
│   │   └── img/
│   │       ├── bg.png
│   │       └── logo.png
│   └── messages/
│       └── messages_de.properties
└── email/
    ├── theme.properties
    ├── html/
    │   ├── template.ftl
    │   └── password-reset.ftl
    └── text/
        └── password-reset.ftl
```

### `login/theme.properties`

```properties
parent=keycloak.v2
import=common/keycloak

styles=css/styles.css css/mustertech.css
```

- **`parent=keycloak.v2`** -- Das Theme erbt von `keycloak.v2`, dem neuen Standard-Theme ab
  Keycloak 26. Dieses basiert auf PatternFly v5 (CSS-Klassen `pf-v5-c-*`). Das ältere
  `keycloak`-Parent nutzt noch PatternFly 3/4 und ist veraltet.
- **`import=common/keycloak`** -- Importiert gemeinsame Ressourcen (Fonts, Icons) aus dem `common`-Theme.
- **`styles=...`** -- Definiert die CSS-Dateien, die geladen werden. `css/styles.css` stammt
  aus dem Parent-Theme (`keycloak.v2`), `css/mustertech.css` ist unsere eigene Datei mit den
  Mustertech-Anpassungen. Die Reihenfolge ist wichtig: unsere Datei kommt zuletzt und
  überschreibt damit die Standard-Styles.

### `login/resources/css/mustertech.css`

```css
:root {
  --pf-v5-global--primary-color--100: #1a5276;
  --pf-v5-global--primary-color--200: #0e3a54;
}

.login-pf body {
  background: url("../img/bg.png") no-repeat center center fixed !important;
  background-size: cover !important;
}
```

Keycloak 26 nutzt [PatternFly v5](https://www.patternfly.org/) als CSS-Framework. Über CSS
Custom Properties (`--pf-v5-global--primary-color--*`) lassen sich die Primärfarben global
ändern, ohne einzelne Komponenten überschreiben zu müssen. Der Hintergrund wird über
`.login-pf body` gesetzt -- wichtig ist hier der Selektor mit `body` als Kindelement, da das
Standard-Theme den Hintergrund auf dem `<body>` innerhalb von `.login-pf` definiert.
Zusätzlich werden in der Datei Styles für Login-Container, Buttons, Links und den Header
definiert -- alle mit den PF5-Selektoren (`.pf-v5-c-button`, `.pf-v5-c-login__main` etc.).

### `login/resources/img/bg.png`

Das Hintergrundbild für die Login-Seite. Wird in `mustertech.css` über den Selektor
`.login-pf body` referenziert und ersetzt das Standard-Hintergrundbild von Keycloak.

### `login/resources/img/logo.png`

Das Firmenlogo der Mustertech GmbH. Keycloak zeigt es automatisch auf der Login-Seite an,
da der Pfad `resources/img/` dem Standard-Theme-Verzeichnis für Bilder entspricht.

### `login/messages/messages_de.properties`

```properties
loginTitle=Anmelden bei Mustertech
doLogIn=Anmelden
doRegister=Registrieren
```

Überschreibt die Standard-Texte mit deutschen Bezeichnungen. Die Property-Keys
(`loginTitle`, `doLogIn`, etc.) sind von Keycloak vorgegeben -- das Theme ersetzt nur die
Werte. Alle Keys, die hier nicht definiert sind, fallen auf die Defaults des Parent-Themes
zurück.

### `email/theme.properties`

```properties
parent=keycloak
```

Erbt alle E-Mail-Templates vom `keycloak`-Theme. Nur die Templates, die wir im `html/`- und
`text/`-Verzeichnis überschreiben, werden durch unsere Version ersetzt.

### `email/html/template.ftl`

Überschreibt den Basis-Wrapper für **alle** HTML-E-Mails. Enthält den Mustertech-Header
(blau mit Firmenname), ein sauberes responsives Layout und den Footer mit Firmenadresse.
Einzelne E-Mail-Templates (z.B. `password-reset.ftl`) setzen die Variable `body` und
inkludieren dann dieses Template.

### `email/html/password-reset.ftl` und `email/text/password-reset.ftl`

Passwort-Reset-E-Mail in HTML- und Text-Version. Die HTML-Version nutzt den
`template.ftl`-Wrapper und enthält einen gestylten Button-Link.

---

## Teil 3: Theme in Docker einbinden

Das Theme ist bereits über die `docker-compose.yml` in diesem Verzeichnis eingebunden. Betrachte das Volume-Mapping:

```yaml
volumes:
  - ../services/keycloak/themes/mustertech:/opt/keycloak/themes/mustertech:ro
```

Das Theme-Verzeichnis wird als Read-Only-Volume in den Keycloak-Container gemountet.

---

## Teil 4: Theme aktivieren

### Schritt 4.1: In Admin-Konsole aktivieren

1. Admin-Konsole -> **Realm settings** -> **Themes**
2. Setze:

| Feld                | Wert         |
|:--------------------|:-------------|
| Login theme         | `mustertech` |
| Account theme       | `keycloak`   |
| Admin console theme | `keycloak`   |
| Email theme         | `mustertech` |

3. Klicke auf **Save**

### Schritt 4.2: Theme testen

1. Öffne ein Inkognito-Fenster
2. Gehe zu: <http://localhost:5173>
3. Klicke auf "Anmelden mit Keycloak"
4. Die Login-Seite sollte das neue Design zeigen

---

## Teil 5: SMTP-Server einrichten (Mailpit)

Um E-Mails lokal testen zu können, verwenden wir **Mailpit** -- einen lokalen SMTP-Server
mit Web-Oberfläche, der alle E-Mails abfängt und anzeigt, ohne sie wirklich zu versenden.

### Schritt 5.1: Mailpit ist bereits in docker-compose.yml

Mailpit läuft als Service in unserer Docker-Umgebung:

```yaml
  assignment-mailpit:
    image: axllent/mailpit:latest
    container_name: assignment-mailpit
    ports:
      - "8025:8025"
      - "1025:1025"
```

Die Web-UI ist unter <http://localhost:8025> erreichbar.

### Schritt 5.2: E-Mail-Adresse für den Admin-User hinterlegen

"Test connection" versendet eine Test-E-Mail an den aktuell eingeloggten User. Der
Keycloak-Admin-User hat standardmäßig keine E-Mail-Adresse -- deshalb muss vorher eine
hinterlegt werden:

1. Wechsle in den **master**-Realm (Dropdown oben links)
2. Navigiere zu **Users** -> klicke auf **admin**
3. Trage eine beliebige E-Mail-Adresse ein (z.B. `admin@mustertech.de`)
4. Klicke auf **Save**
5. Wechsle zurück in den **mustertech**-Realm

### Schritt 5.3: SMTP in Keycloak konfigurieren

1. Admin-Konsole -> **Realm settings** -> **Email**
2. Konfiguriere:

| Feld     | Wert                        |
|:---------|:----------------------------|
| From     | `noreply@mustertech.de`     |
| Host     | `assignment-mailpit`        |
| Port     | `1025`                      |

3. Klicke auf **Save**
4. Klicke auf **Test connection** -- in Mailpit (<http://localhost:8025>) sollte eine Test-E-Mail erscheinen

### Schritt 5.4: Passwort-Reset testen

1. Öffne <http://localhost:5173> im Inkognito-Fenster
2. Klicke auf **Anmelden mit Keycloak** -> **Passwort vergessen?**
3. Gib den Benutzernamen eines bestehenden Users ein
4. Öffne <http://localhost:8025> -- die Passwort-Reset-E-Mail sollte mit dem Mustertech-Design erscheinen

---

## Teil 6: E-Mail-Templates -- Code-Walkthrough

Die E-Mail-Templates liegen bereits fertig im Theme. Schauen wir uns den Aufbau an.

### Schritt 6.1: template.ftl -- Basis-Layout

Die Datei `services/keycloak/themes/mustertech/email/html/template.ftl` definiert das
gemeinsame Layout für **alle** HTML-E-Mails. Einzelne E-Mail-Templates setzen die
FreeMarker-Variable `body` und inkludieren dann dieses Template:

```html
<!-- Auszug: Header und Body-Platzhalter -->
<td style="background-color: #0066cc; padding: 24px; text-align: center;">
  <h1 style="color: #ffffff;">Mustertech GmbH</h1>
</td>
...
<td style="background-color: #ffffff; padding: 32px 24px;">
  ${body}
</td>
```

### Schritt 6.2: password-reset.ftl (HTML)

Die Datei `services/keycloak/themes/mustertech/email/html/password-reset.ftl` setzt den
`body` und inkludiert das Template:

```html
<#assign body>
  <p>Hallo ${"$"}{user.firstName!"Benutzer"},</p>
  <p>Du hast eine Anfrage zum Zurücksetzen deines Passworts gestellt.</p>
  <p style="text-align: center;">
    <a href="${"$"}{link}" style="padding: 12px 32px; background-color: #0066cc;
       color: #ffffff; text-decoration: none; border-radius: 4px;">
      Passwort zurücksetzen
    </a>
  </p>
  ...
</#assign>
<#include "template.ftl">
```

### Schritt 6.3: password-reset.ftl (Text)

Die Plain-Text-Version unter `email/text/password-reset.ftl` enthält den gleichen Inhalt
ohne HTML-Formatierung -- für E-Mail-Clients, die kein HTML unterstützen.

---

## Teil 7: Bonus -- Theme anpassen

Jetzt bist du dran: Ändere einzelne Aspekte des Themes und beobachte die Auswirkungen live.

> **Tipp:** Nach jeder CSS-Änderung die Seite mit **Ctrl+Shift+R** (Hard Reload)
> aktualisieren, damit der Browser-Cache umgangen wird.

### Aufgabe 7.1: Button- und Akzentfarbe ändern

Die auffälligsten Elemente auf der Login-Seite sind der **Anmelde-Button** und der
**farbige Akzent-Strich** am oberen Rand des Login-Containers.

1. Öffne `../services/keycloak/themes/mustertech/login/resources/css/mustertech.css`
2. Ändere die Button-Farbe -- zum Beispiel auf Grün:

```css
.pf-v5-c-button.pf-m-primary {
  background-color: #2e7d32;
  border-color: #2e7d32;
}

.pf-v5-c-button.pf-m-primary:hover,
.pf-v5-c-button.pf-m-primary:focus {
  background-color: #1b5e20;
  border-color: #1b5e20;
}
```

3. Ändere den Akzent-Strich oben am Login-Container passend dazu:

```css
.pf-v5-c-login__main {
  border-top: 4px solid #2e7d32;
  /* ... restliche Properties bleiben */
}
```

4. Lade die Login-Seite neu -- der Button und der Akzent-Strich sollten jetzt grün sein

**Frage:** Welche weiteren Stellen müsste man anpassen, um ein durchgängig grünes
Farbschema zu bekommen?

### Aufgabe 7.2: Login-Titel-Farbe und Schriftgröße anpassen

Der Header-Text (`#kc-header-wrapper`) zeigt den Realm-Namen. Passe ihn an:

1. Ändere die Schriftfarbe auf einen hellen Gelbton:

```css
#kc-header-wrapper {
  color: #ffd54f !important;
}
```

2. Experimentiere mit weiteren Eigenschaften:

| Eigenschaft      | Beispielwert | Effekt               |
|:-----------------|:-------------|:---------------------|
| `font-size`      | `2.5rem`     | Größerer Titel       |
| `text-transform` | `none`       | Keine Großbuchstaben |
| `letter-spacing` | `0.1em`      | Weiter gesperrt      |
| `font-weight`    | `400`        | Dünnere Schrift      |

### Aufgabe 7.3: Login-Card stylen

Der Login-Container (`.pf-v5-c-login__main`) lässt sich visuell stark verändern:

1. Ändere die obere Akzentlinie:

```css
.pf-v5-c-login__main {
  border-top: 4px solid #ff9800;   /* Orange statt Blau */
}
```

2. Probiere weitere Varianten:

| Eigenschaft | Beispielwert | Effekt |
| :--- | :--- | :--- |
| `border-top` | `none` | Keine Akzentlinie |
| `border-radius` | `0` | Eckige Karte |
| `box-shadow` | `none` | Kein Schatten |
| `background-color` | `rgba(255,255,255,0.9)` | Leicht transparent |

### Aufgabe 7.4: Hintergrundbild durch Farbverlauf ersetzen (Optional)

Ersetze das Hintergrundbild durch einen CSS-Gradient:

```css
.login-pf body {
  background: linear-gradient(135deg, #1a5276 0%, #2e86c1 50%, #85c1e9 100%) !important;
  background-size: cover !important;
}
```

Experimentiere mit Richtung (`135deg`), Farben und Stopps.

### Aufgabe 7.5: Dark Mode erstellen (Optional)

Baue einen dunklen Login-Bildschirm:

1. Dunkler Hintergrund:

```css
.login-pf body {
  background: #1a1a2e !important;
}
```

2. Dunkle Login-Card:

```css
.pf-v5-c-login__main {
  background-color: #16213e;
  border-top: 4px solid #e94560;
  color: #eee;
}
```

3. Helle Überschrift:

```css
.pf-v5-c-login__main-header .pf-v5-c-title {
  color: #e94560;
}
```

**Frage:** Welche Elemente musst du noch anpassen, damit der Dark Mode konsistent
aussieht? (Tipp: Input-Felder, Labels, Footer)

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Theme-Ordnerstruktur erstellt
- [x] CSS für Corporate Design angepasst
- [x] Theme in Docker eingebunden
- [x] Theme im Realm aktiviert
- [x] E-Mail-Templates angepasst

**Weiter:** Modul 09b - Admin REST API nutzen!

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

### Theme erscheint nicht in der Auswahl

- Container neu starten (Theme wird beim Start geladen)
- Volume-Pfad in docker-compose.yml prüfen
- theme.properties vorhanden und korrekt?

### CSS-Änderungen werden nicht angezeigt

- Browser-Cache leeren (Ctrl+Shift+R)
- Inkognito-Fenster verwenden
- Das Theme-Caching ist in dieser Übung bereits deaktiviert
  (`--spi-theme-cache-themes=false` in docker-compose.yml). Falls die Änderungen trotzdem
  nicht sichtbar sind, Keycloak neu starten: `docker compose restart assignment-keycloak`

### E-Mails werden nicht gesendet

- SMTP in Realm settings -> Email konfiguriert? (Host: `assignment-mailpit`, Port: `1025`)
- Mailpit-Container läuft? (`docker compose ps assignment-mailpit`)
- Web-UI prüfen: <http://localhost:8025>
