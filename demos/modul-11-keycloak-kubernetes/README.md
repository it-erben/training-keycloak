# Live-Demo Modul 11: Keycloak auf Kubernetes

Operator, Self-Healing und Rolling Update live zeigen, auf dem Cluster aus Lab 11. Der Fokus liegt auf
das, was der Operator aus der Custom Resource macht.

| Demo | Thema | Dauer |
| :--- | :--- | :--- |
| Demo 1 | Von der CR zum StatefulSet | 3 Min |
| Demo 2 | Self-Healing: StatefulSet löschen | 2 Min |
| Demo 3 | Skalieren und Cluster-View | 3 Min |
| Demo 4 | Rolling Update beobachten | 3 Min |

## Voraussetzungen

- Docker Desktop, minikube, kubectl
- Lab 11 bis einschließlich Teil 5 durchgeführt: Operator, PostgreSQL, Keycloak-CR, Ingress und
  Realm-Import sind angewendet

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
kubectl -n keycloak get keycloak keycloak -o yaml | less
```

Auf `spec` zeigen: `instances`, `db`, `hostname`, `proxy`. Dann nach unten zu `status.conditions`
scrollen: `Ready`, `HasErrors`, `RollingUpdate`.

### Schritt 2: Erzeugte Ressourcen zeigen

```bash
kubectl -n keycloak get statefulset,service,secret
```

Alle drei Ressourcen stammen aus der CR; keine wurde von Hand angelegt.

### Schritt 3: Umgebung eines Pods

```bash
kubectl -n keycloak get pod keycloak-0 -o yaml | grep -A1 "name: KC_"
```

Auf `KC_DB_URL_HOST`, `KC_HOSTNAME`, `KC_CACHE_STACK` und `KC_PROXY_HEADERS` zeigen: der Operator
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

```bash
kubectl -n keycloak patch keycloak keycloak --type merge -p '{"spec":{"instances":2}}'
kubectl -n keycloak get pods -w
```

### Schritt 2: Cluster-View zeigen

```bash
kubectl -n keycloak logs keycloak-1 | grep "cluster view"
```

Auf die Mitgliederliste `(2) [keycloak-0-…, keycloak-1-…]` zeigen. Dann den Headless Service:

```bash
kubectl -n keycloak get endpointslices -l kubernetes.io/service-name=keycloak-discovery
```

Die Pod-IPs kommen aus dem DNS des Headless Service.

---

## Demo 4: Rolling Update beobachten

### Schritt 1: Konfiguration ändern

```bash
kubectl -n keycloak patch keycloak keycloak --type merge \
  -p '{"spec":{"additionalOptions":[{"name":"metrics-enabled","value":"true"},{"name":"log-level","value":"INFO,org.infinispan:DEBUG"}]}}'
```

### Schritt 2: Im zweiten Terminal beobachten

`keycloak-1` wird beendet und neu gestartet, erst danach `keycloak-0`. Zu jedem Zeitpunkt
bedient ein Pod den Login. Zwischendurch:

```bash
kubectl -n keycloak get keycloak keycloak -o jsonpath='{.status.conditions[?(@.type=="RollingUpdate")]}'
```

Ein Versions-Upgrade läuft denselben Weg, mit `spec.image` statt einer Option.

---

## Aufräumen

```bash
kubectl -n keycloak patch keycloak keycloak --type merge \
  -p '{"spec":{"instances":1,"additionalOptions":[{"name":"metrics-enabled","value":"true"}]}}'
```

Der Cluster bleibt für das Lab bestehen; `minikube delete` erst nach dem letzten Lab-Teil.
