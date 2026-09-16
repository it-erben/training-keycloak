# Live-Demo Modul 11: Keycloak auf Kubernetes

Operator, Self-Healing und Rolling Update live zeigen, auf dem Cluster aus Lab 11. Der Fokus liegt auf
dem, was der Operator aus der Custom Resource macht.

| Demo   | Thema                             |
| :----- | :-------------------------------- |
| Demo 1 | Von der CR zum StatefulSet        |
| Demo 2 | Self-Healing: StatefulSet löschen |
| Demo 3 | Skalieren und Cluster-View        |
| Demo 4 | Rolling Update beobachten         |

## Voraussetzungen

- Docker Desktop, minikube, kubectl
- Lab 11 bis einschließlich Teil 5 durchgeführt: Operator, PostgreSQL, Keycloak-CR, Ingress und
  Realm-Import sind angewendet
- Unter Windows: PowerShell und die Windows-Programme `minikube` und `kubectl`, wie in der
  [Windows-Einrichtung](../../labs/WINDOWS.md) beschrieben

## Setup

```bash
cd labs/assignments/modul-11-kubernetes
kubectl -n keycloak get keycloak,pods
```

Die CR `keycloak` steht auf `Ready`, `keycloak-0` und `postgres-0` laufen. Für Demo 4 zwei Terminals
öffnen; eines zeigt dauerhaft `kubectl -n keycloak get pods -w`.

---

## Demo 1: Von der CR zum StatefulSet

### Schritt 1: CR zeigen

```bash
kubectl -n keycloak get keycloak keycloak -o yaml
```

Auf `spec` zeigen: `instances`, `db`, `hostname`, `proxy`. Dann nach unten zu `status.conditions`
scrollen: `Ready`, `HasErrors`, `RollingUpdate`.

### Schritt 2: Erzeugte Ressourcen zeigen

```bash
kubectl -n keycloak get statefulset,service,secret
```

Alle drei Ressourcen stammen aus der CR; keine wurde von Hand angelegt.

### Schritt 3: Umgebung eines Pods

**Bash:**

```bash
kubectl -n keycloak get pod keycloak-0 -o yaml | grep -A1 "name: KC_"
```

**PowerShell:**

```powershell
kubectl -n keycloak get pod keycloak-0 -o yaml | Select-String "name: KC_" -Context 0,1
```

Auf `KC_DB_URL_HOST`, `KC_HOSTNAME` und `KC_PROXY_HEADERS` zeigen: der Operator
übersetzt die CR-Felder in dieselben Optionen wie in den Compose-Labs.

---

## Demo 2: Self-Healing: StatefulSet löschen

### Schritt 1: StatefulSet löschen

```bash
kubectl -n keycloak delete statefulset keycloak
kubectl -n keycloak get statefulset,pods -w
```

### Schritt 2: Beobachten

Innerhalb weniger Sekunden legt der Operator das StatefulSet neu an, der Pod startet. Der Operator
stellt den Zustand aus der CR wieder her, auch nach dem Löschen des StatefulSets.

---

## Demo 3: Skalieren und Cluster-View

### Schritt 1: Instanzen erhöhen

**Bash:**

```bash
kubectl -n keycloak patch keycloak keycloak --type merge -p '{"spec":{"instances":2}}'
```

**PowerShell:**

```powershell
$patchFile = [IO.Path]::GetTempFileName()
@{spec = @{instances = 2}} | ConvertTo-Json -Depth 5 | Set-Content $patchFile -Encoding Ascii
kubectl -n keycloak patch keycloak keycloak --type merge --patch-file $patchFile
Remove-Item $patchFile
```

Die Datei vermeidet, dass PowerShell 5.1 JSON-Anführungszeichen beim Aufruf von `kubectl`
entfernt. Warte anschließend in beiden Shells auf das StatefulSet:

```bash
kubectl -n keycloak wait "--for=jsonpath={.spec.replicas}=2" statefulset/keycloak --timeout=300s
kubectl -n keycloak rollout status statefulset/keycloak --timeout=300s
kubectl -n keycloak get pods
```

Der erste Befehl wartet darauf, dass der Operator die CR in das StatefulSet übernommen hat.
Erst danach prüfst du, ob die beiden Pods bereit sind.

### Schritt 2: Cluster-View zeigen

**Bash:**

```bash
kubectl -n keycloak logs keycloak-1 | grep "cluster view"
```

**PowerShell:**

```powershell
kubectl -n keycloak logs keycloak-1 | Select-String "cluster view"
```

Auf die Mitgliederliste `(2) [keycloak-0-…, keycloak-1-…]` zeigen. Dann den Headless Service:

```bash
kubectl -n keycloak get endpointslices -l kubernetes.io/service-name=keycloak-discovery
```

Die EndpointSlices zeigen die Pod-IPs hinter dem Headless Service. Zur Cluster-Discovery nutzt
Keycloak 26.5 standardmäßig die gemeinsame Datenbank (`jdbc-ping`). Zeige den Stack im Log:

```bash
kubectl -n keycloak logs keycloak-1 | grep "Starting JGroups channel"
```

In PowerShell verwendest du:

```powershell
kubectl -n keycloak logs keycloak-1 | Select-String "Starting JGroups channel"
```

---

## Demo 4: Rolling Update beobachten

### Schritt 1: Konfiguration ändern

**Bash:**

```bash
kubectl -n keycloak patch keycloak keycloak --type merge \
  -p '{"spec":{"additionalOptions":[{"name":"metrics-enabled","value":"true"},{"name":"log-level","value":"INFO,org.infinispan:DEBUG"}]}}'
```

**PowerShell:**

```powershell
$patchFile = [IO.Path]::GetTempFileName()
$options = @(
  @{name = "metrics-enabled"; value = "true"}
  @{name = "log-level"; value = "INFO,org.infinispan:DEBUG"}
)
@{spec = @{additionalOptions = $options}} |
  ConvertTo-Json -Depth 5 | Set-Content $patchFile -Encoding Ascii
kubectl -n keycloak patch keycloak keycloak --type merge --patch-file $patchFile
Remove-Item $patchFile
```

### Schritt 2: Im zweiten Terminal beobachten

`keycloak-1` wird beendet und neu gestartet, erst danach `keycloak-0`. Beobachte, ob mindestens
ein Pod Ready bleibt, und lade parallel die Login-Seite. Kurze Fehler oder Timeouts sind trotz
Ready-Pod möglich, etwa beim Umschalten des Ingress auf den Ersatz-Pod. Zwischendurch:

```bash
kubectl -n keycloak get keycloak keycloak -o jsonpath='{.status.conditions[?(@.type=="RollingUpdate")]}'
```

In PowerShell liest du die Bedingungen aus dem JSON:

```powershell
$kcState = kubectl -n keycloak get keycloak keycloak -o json | ConvertFrom-Json
$kcState.status.conditions | Where-Object type -eq "RollingUpdate"
```

Ein Imagewechsel unterliegt `spec.update.strategy`. Der Standard `RecreateOnImageChange`
ersetzt alle Pods gemeinsam. Erst mit explizitem `Auto` prüft der Operator, ob das neue Image
für ein Rolling Update geeignet ist; andernfalls bleibt ein Recreate erforderlich.

---

## Aufräumen

**Bash:**

```bash
kubectl -n keycloak patch keycloak keycloak --type merge \
  -p '{"spec":{"instances":1,"additionalOptions":[{"name":"metrics-enabled","value":"true"}]}}'
```

**PowerShell:**

```powershell
$patchFile = [IO.Path]::GetTempFileName()
@{spec = @{instances = 1; additionalOptions = @(@{name = "metrics-enabled"; value = "true"})}} |
  ConvertTo-Json -Depth 5 | Set-Content $patchFile -Encoding Ascii
kubectl -n keycloak patch keycloak keycloak --type merge --patch-file $patchFile
Remove-Item $patchFile
```

Der Cluster bleibt für das Lab bestehen; `minikube delete` erst nach dem letzten Lab-Teil.
