# Kursumgebung unter Windows

Die Compose-Befehle funktionieren in PowerShell und Bash. Für die Bash-Skripte der
Identity-Provider- und PCI-DSS-Demos brauchst du zusätzlich Ubuntu unter WSL 2 mit
Python und Zugriff auf Docker Desktop. Das Kubernetes-Lab enthält eigene
PowerShell-Varianten und verwendet die unter Windows installierten Programme
`minikube` und `kubectl`.

## Docker in Ubuntu freigeben

Prüfe in PowerShell, ob Ubuntu mit Version `2` aufgeführt ist:

```powershell
wsl --list --verbose
```

Falls Ubuntu fehlt, installiere es nach der
[WSL-Anleitung von Microsoft](https://learn.microsoft.com/windows/wsl/install).
Öffne Docker Desktop und aktiviere unter **Settings -> Resources -> WSL integration**
die Distribution **Ubuntu**. Übernimm die Änderung mit **Apply**. Docker Desktop
muss das WSL-2-Backend verwenden und Linux-Container ausführen.
Siehe auch [Docker Desktop mit WSL](https://docs.docker.com/desktop/features/wsl/).

Starte Ubuntu aus PowerShell:

```powershell
wsl -d Ubuntu
```

Prüfe in dieser Bash-Sitzung:

```bash
docker version
docker compose version
python3 --version
curl --version
```

`docker version` muss einen **Server** anzeigen; eine installierte Docker-CLI allein
reicht nicht. Falls Python oder curl fehlen, installiere sie in Ubuntu:

```bash
sudo apt update
sudo apt install python3 curl
```

Eine zweite Docker Engine in Ubuntu ist für diesen Aufbau nicht nötig.

## Den Windows-Checkout verwenden

Das Windows-Laufwerk `C:` ist in WSL unter `/mnt/c` erreichbar. Passe den Benutzernamen
und gegebenenfalls den Desktop-Pfad an, wenn dein Desktop etwa unter OneDrive liegt:

```bash
cd /mnt/c/Users/DEIN_BENUTZER/Desktop/training-keycloak
cd demos/modul-07-identity-provider
docker compose up -d
bash setup.sh
```

Der Browser läuft weiterhin unter Windows und öffnet die `localhost`-Adressen aus der
jeweiligen Demo. Vor dem nächsten Lab beendest du dessen Vorgänger mit
`docker compose down -v` im zugehörigen Verzeichnis.

Die Datei `.gitattributes` hält Bash-Skripte auch bei einem Windows-Checkout mit
`core.autocrlf=true` auf LF-Zeilenenden. Für einen älteren Checkout, in dem noch CRLF
vorliegen, steht die gezielte Korrektur im
[Troubleshooting](assignments/TROUBLESHOOTING.md#bash-skripte-melden-pipefail-oder-bashr).

## PowerShell und Bash unterscheiden

Die Bash-Skripte und Bash-spezifischen API-Abfragen der Compose-Labs und Demos führst du
in Ubuntu aus. Dazu gehören `NAME=wert`, `grep`, `base64 -d` und `\` für mehrzeilige
Befehle. Wo eine PowerShell-Variante vorhanden ist, kannst du stattdessen diese verwenden;
sie nutzt etwa `$NAME`, `Select-String`, .NET und den Backtick.

Für [Modul 11](assignments/modul-11-kubernetes/README.md) und die zugehörige Demo bleibst
du in PowerShell, damit `minikube`, `kubectl` und `minikube tunnel` denselben
Windows-Kontext verwenden. Bei getrennten Blöcken wählst du **PowerShell**. Gemeinsame
Blöcke ohne eigene Shell-Überschrift führst du dort ebenfalls in PowerShell aus; die
einfachen `kubectl`- und `minikube`-Befehle funktionieren in beiden Shells. OpenSSL aus
Git for Windows wird direkt in PowerShell aufgerufen; dadurch bleibt das
Zertifikats-Subject unverändert.
