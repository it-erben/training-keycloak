# Arbeitsregeln

## Ton

- Knapp. Sag, was zu sagen ist, dann Schluss. Kein Vorgeplänkel, keine
  Zusammenfassung des gerade Getanen, kein „gute Frage“, kein Wiederholen der
  Aufgabe.
- Keine Füll-Adjektive (robust, nahtlos, mächtig, umfassend, produktionsreif).
  Knapp sagen, was der Code tut, nicht wie gut er ist. Nicht paraphrasieren, was
  die nächsten Zeilen tun. Stattdessen das WARUM und WIE erklären, wenn das dem
  Verständnis wirklich hilft.
- Docs und READMEs: was es ist, wie man es nutzt, was es bereitstellt. Sonst
  nichts.
- Commit-Nachrichten: conventional-commit, Imperativ, möglichst einzeilig. Den
  Scope richtig wählen — Release-Tooling routet unter Umständen darüber. Breaking
  Changes bekommen ein `!` (`feat(api)!: …`) oder einen `BREAKING CHANGE:`-Footer.
  Betreffzeile ≤ 72 Zeichen, Imperativ („add“, „fix“, nicht „added“, „fixes“).
  Body auf 72 Zeichen umbrechen.
- Kleine, fokussierte Commits bevorzugen. Release-Tooling leitet Versionssprünge
  und Changelog oft aus den Commit-Betreffzeilen ab.
- Keine Ticket-Nummern in Code, Commits oder Docs.
- Kommentare erklären das *Warum*, nicht das *Was*. Code-Kommentare benennen die
  Absicht oder eine Einschränkung, die der Code nicht zeigen kann. Kommentare
  löschen, die den Code nur wiederholen.
- Kommentare und Docs immer als Ganzes betrachten. Nie nur anhängen. Im Kontext
  prüfen und auf den faktischen Stand bringen. Im Zweifel im Code recherchieren.
  Veraltete und aus dem Kontext gefallene Verweise entfernen, ebenso frühere
  Beobachtungen, Schilderungen von Situationen, die zu einer früheren Änderung
  führten, Maschinennamen oder -adressen sowie jede Vermutung über die
  nachgelagerte Nutzung dieses Repos und seiner Artefakte — abgesehen von
  gültigen, aktuellen Beispielen.
- Auf ein anderes Repository oder Projekt nur verweisen, wenn dessen Zustand der
  unmittelbare Grund für die Änderung ist (ein Dependency-Bump, ein eingespielter
  Fix, ein an eine veröffentlichte Version gebundener API-Vertrag). Kontext für
  Reviewer, Dank oder Querverweise gehören in den PR-Thread oder ein Issue, nicht
  in den Commit.
- Deklarative Fakten schreiben. Keine Personalpronomen („ich“, „wir“, „du“).
  Keine Leseransprache: kein „beachte, dass…“, „wie man sieht…“, „wir haben uns
  entschieden…“, „das sollte helfen…“. Die Regel gilt für Dokumentation, die
  ein Artefakt beschreibt. Ausgenommen sind Folien, Labs und die Materialien
  zum Vortragen, siehe unten.
- Nicht erzählen. Keine Historie, was zuerst versucht wurde, was scheiterte oder
  welche Alternativen erwogen wurden.
- Keine Füll-Verben ohne Konkretes. „Aufräumen“, „verbessern“, „refactoren“
  allein sagen nichts; entweder die tatsächliche Änderung benennen oder die Zeile
  weglassen.
- Keine Checklisten, keine „Summary“-/„Test plan“-Abschnitte, keine
  Marketing-Sprache, keine Emojis.

## Folien

Elf Marp-Decks unter `slides/<NN-thema>/slides.md`. Lehrmaterial, das die
Pronomen- und Leseransprache-Regel aufhebt.

- **Geduzt.** „du“, „dir“, „dein“. Im gesamten `slides/`-Baum steht keine
  einzige Sie-Form.
- Frontmatter: `header: "Modul NN: Thema"`, `footer: "CC BY-NC-SA 4.0,
  Alexander Erben"`, `paginate: true`.
- Titelfolie ist `# Modul NN`, darunter `## Thema`.
- `## Lernziele` als zweite Folie in allen elf Decks, mit der Einleitung
  „Nach diesem Modul kannst du:“. Jedes Ziel ein Satz mit dem Fachbegriff
  fett.
- **Folientitel sind hierarchisch nummeriert**: `## 1. Was ist ein Client?`
  für den Abschnitt, `## 1.1 Client-Typen (Access Type)` für die Folie darin.
  Beim Einfügen die Nummern des Abschnitts nachziehen.
- Ein Begriff wird zuerst in einem Satz definiert, dann als Bullet-Liste seiner
  Eigenschaften aufgeschlüsselt, jede mit fettem Feldnamen und Beispielwert in
  Backticks: **Client ID:** Eindeutige ID (z.B. `my-webapp`).
- `> **Merke:**` als Blockzitat für den Satz, der hängenbleiben soll.
  Sparsam — bisher drei im ganzen Repo.
- Sicherheitsrelevante Stellen benennen die Konsequenz, nicht nur die
  Einstellung. Ein Redirect-URI-Feld ist nicht „wichtig“, sondern entscheidet,
  wohin Keycloak den User zurückschickt.

## Lab-Anleitungen

Sechzehn Übungen unter `labs/assignments/modul-NN[x]-thema/`. Sie bauen
aufeinander auf: über die ganze Schulung entsteht ein Mitarbeiterportal der
fiktiven Mustertech GmbH.

- Geduzt wie die Folien.
- Titel ist `# Modul NN: Thema`, gleichlautend mit dem Deck.
- `## Übungsziel` mit „Am Ende dieser Übung hast du:“ und Ergebnisliste im
  Perfekt, danach `**Geschätzte Dauer:**` in Minuten.
- `## Voraussetzungen` startet die Umgebung mit `docker compose up -d` und
  sagt, woran das Bereitsein erkennbar ist. `modul-11-kubernetes` startet
  stattdessen minikube; der Zustand kommt dort aus `manifests/`.
- Ein `> **Hinweis:**`-Blockzitat weist auf den Container-Namenskonflikt mit
  der vorherigen Übung hin und verlinkt nach
  `../TROUBLESHOOTING.md`. Jedes Lab, das eigene Container startet, braucht
  diesen Hinweis.
- Dann `## Teil N: …` als fachlicher Abschnitt, darin `### Schritt N.M: …` als
  einzelner Handgriff durch die Admin-Konsole.
- Ein Suffix-Buchstabe teilt ein Modul in mehrere Labs (`modul-06a` bis
  `modul-06d`). Beim Einfügen den Buchstaben fortsetzen, nicht umnummerieren.
- Der Zustand kommt aus `realm-import.json`, nicht aus Klickanweisungen. Was
  das Lab lehrt, wird geklickt; alles andere wird importiert.
- Knapp auf Satzebene gilt weiterhin: keine Füll-Adjektive, kein Marketing,
  keine Zusammenfassung des Abschnitts darüber.

## Materialien zum Vortragen

`materials/*.md` sind keine Anleitungen, sondern Vorlagen für Kurzvorträge der
Teilnehmenden.

- Beginnen mit `## Deine Aufgabe` und dem Zeitrahmen („~10 Minuten“).
- Sagen ausdrücklich, dass das Material ergänzt und angepasst werden darf.
- Danach der Stoff in nummerierten Abschnitten wie auf den Folien.

## Vor dem Abschluss

- Lint, Tests und Build des Projekts für alles Berührte ausführen.
- `pre-commit run --all-files` laufen lassen und alle Befunde beheben.
- Ein berührtes Lab wirklich hochfahren: `docker compose up -d` im
  Lab-Verzeichnis, die Schritte durchklicken, danach `docker compose down -v`.
  Ohne `-v` bleibt das Volume liegen und das nächste Lab startet mit fremdem
  Realm-Zustand. Für `modul-11-kubernetes` gilt dasselbe mit `minikube start`
  und `minikube delete`; die Manifeste zusätzlich mit `kubeconform` gegen die
  Operator-CRDs prüfen.
- Nicht „fertig“ behaupten, ohne die Prüfung ausgeführt zu haben. Belege vor
  Behauptungen.
- Alle TODO-Marker entfernen, die du in deiner Sitzung hinzugefügt hast, und
  nacharbeiten — oder dem Nutzer sagen, dass ein Follow-up nötig ist. Alle Marker
  und Verweise auf deine eigene Aufgabenliste oder historische Arbeitsschritte
  (P2, P3a, Item 1, Task A usw.) samt ihrer Erzählung entfernen. Wenn wirklich
  etwas offen bleibt, dem Nutzer außerhalb von Code, Docs, Markdown, Kommentaren,
  PR-Beschreibungen, Commit-Nachrichten oder allem anderen in diesem Repo und
  seiner angeschlossenen Pipeline Bescheid geben.

## Aufbau dieses Repos

Keycloak-Schulung, elf Module.

- `slides/01-…` bis `slides/11-…` — die Decks.
- `labs/assignments/modul-NN…` — sechzehn Übungen, je mit
  `docker-compose.yml`, meist mit `realm-import.json` und `screenshots/`.
  `modul-11-kubernetes` hat statt Compose ein `manifests/`-Verzeichnis mit
  dem Realm als `KeycloakRealmImport`-CR.
- `labs/assignments/services/` — der Anwendungscode, den alle Labs teilen:
  `portal-frontend` (React SPA mit OIDC und PKCE), `portal-api` (Express,
  Token-Validierung), `sync-service` (Client Credentials), `management-cli`,
  `keycloak`.
- `labs/assignments/TROUBLESHOOTING.md` — die Sammelstelle für Fehlerbilder.
  Neue Stolpersteine dorthin, nicht in das einzelne Lab.
- `demos/modul-NN-thema/` — elf Vorführungen des Trainers.
- `materials/` — zwei Vortragsvorlagen zu OAuth-Flows.

## Fallstricke dieses Repos

- **Die `cd`-Pfade in den Lab-READMEs sind relativ zu `labs/`, nicht zur
  Wurzel.** Dort steht `cd assignments/modul-04-benutzerverwaltung`, der
  tatsächliche Pfad ist `labs/assignments/modul-04-benutzerverwaltung`.
- **Die Labs teilen sich Container-Namen.** Wer die vorherige Übung nicht mit
  `docker compose down -v` beendet, bekommt einen Namenskonflikt. Deshalb der
  Hinweis in jedem Lab; er ist kein Beiwerk.
- **`labs/modul-06a-sso-portal/` ist ein leeres Verzeichnis** neben
  `labs/assignments/`. Das echte Lab liegt unter
  `labs/assignments/modul-06a-sso-portal`.
- **`tools/screenshots/` enthält nur ein ignoriertes `node_modules`.** Es gibt
  keinen versionierten Quellcode für das Screenshot-Werkzeug.
- **Nicht jedes Lab bringt alles mit.** `modul-03-installation` hat kein
  `realm-import.json` — dort ist das Aufsetzen die Übung. Fünf Labs haben
  keine `screenshots/`, eines keine geschätzte Dauer.
- **Die Modulnummern von Labs und Demos decken sich nicht durchgängig.** Zu
  `demos/modul-06d-client-role-isolation` gehört `labs/assignments/
  modul-06d-logout` — gleicher Buchstabe, anderes Thema. Nie von der Nummer
  auf die Zuordnung schließen.
- **„Mustertech GmbH“ ist auch die Beispielfirma im Elastic-Kurs.** Innerhalb
  dieses Repos bleibt sie ein Mitarbeiterportal; keine Inhalte zwischen den
  Kursen übernehmen, nur weil der Name derselbe ist.
- **markdownlint erlaubt hier 120 Zeichen.** Die Folien nutzen das aus, die
  Labs brechen bei rund 100 um. Pro Datei beim vorhandenen Maß bleiben.
- **Die CI hat eine `deploy`-Stage, aber keine `training-deploy`-Komponente.**
  Es entsteht ein PDF und ein Release-Tag, aber keine Website.
- **Die CI läuft auf zwei Plattformen.** `.gitlab-ci.yml` bindet die
  GitLab-Komponenten ein, `.github/workflows/ci.yml` ruft `lint.yml`,
  `slides.yml`, `release.yml` und `pages.yml` aus
  `it-erben/ci`. Die PDFs gehen dort auf
  GitHub Pages.
