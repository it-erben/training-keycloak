# Modul 11: Keycloak auf Kubernetes

## Übungsziel

Am Ende dieser Übung hast du:

- Einen lokalen Kubernetes-Cluster mit minikube gestartet
- Den Keycloak Operator installiert und Keycloak über eine Custom Resource deployt
- PostgreSQL als StatefulSet mit persistentem Volume angebunden
- Keycloak per Ingress mit TLS-Terminierung erreichbar gemacht
- Den Realm `mustertech` über eine `KeycloakRealmImport`-Ressource importiert
- Keycloak auf zwei Instanzen skaliert und den Infinispan-Cluster beobachtet
- Health-Endpoints und Metriken über den Management-Port abgefragt

**Geschätzte Dauer:** 45-60 Minuten

---

## Voraussetzungen

- Docker Desktop installiert und gestartet, mit mindestens 6 GB RAM für Container
- [minikube](https://minikube.sigs.k8s.io/docs/start/) und
  [kubectl](https://kubernetes.io/docs/tasks/tools/) installiert
- `openssl` (unter Windows in der Git Bash enthalten)

Diese Übung nutzt kein `docker compose`. Der Cluster läuft als Container in Docker Desktop.

> **Hinweis:** Falls die Container der vorherigen Übung noch laufen, stoppe
> diese zuerst mit `docker compose down -v` im Verzeichnis der vorherigen Übung.
> Der Cluster braucht den Arbeitsspeicher, den die Container sonst belegen.
> Details siehe [Troubleshooting](../TROUBLESHOOTING.md#container-name-konflikt).

### Umgebung starten

```bash
cd assignments/modul-11-kubernetes
minikube start --driver=docker --cpus=4 --memory=6144
minikube addons enable ingress
```

Der Cluster ist bereit, wenn `kubectl get nodes` den Knoten `minikube` mit Status `Ready` zeigt
und `kubectl -n ingress-nginx get pods` den Pod `ingress-nginx-controller-…` mit `Running` listet.

### Architektur

```
                 https://keycloak.mustertech.test
                              |
                              v
        +----------------------------------------------+
        |  Namespace ingress-nginx                     |
        |  Ingress-Controller (TLS-Terminierung)       |
        +----------------------+-----------------------+
                               | HTTP + X-Forwarded-*
        +----------------------v-----------------------+
        |  Namespace keycloak                          |
        |                                              |
        |  Service keycloak-service :8080              |
        |     |                                        |
        |  StatefulSet keycloak  (Pods keycloak-0, -1) |
        |     |   ^                                    |
        |     |   | erzeugt und überwacht              |
        |     |  Deployment keycloak-operator          |
        |     v                                        |
        |  Service postgres :5432                      |
        |  StatefulSet postgres + PersistentVolume     |
        +----------------------------------------------+
```

Alle Manifeste liegen unter `manifests/` und werden in der Reihenfolge ihrer Nummern angewendet.

---

## Teil 1: Operator installieren

### Schritt 1.1: Namespace anlegen

```bash
kubectl apply -f manifests/00-namespace.yaml
```

Der Namespace muss `keycloak` heißen, weil das `ClusterRoleBinding` des Operators fest auf den
ServiceAccount `keycloak-operator` in diesem Namespace verweist.

### Schritt 1.2: CRDs und Operator anwenden

```bash
KC_RES=https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.5.7/kubernetes
kubectl -n keycloak apply -f $KC_RES/keycloaks.k8s.keycloak.org-v1.yml
kubectl -n keycloak apply -f $KC_RES/keycloakrealmimports.k8s.keycloak.org-v1.yml
kubectl -n keycloak apply -f $KC_RES/kubernetes.yml
```

Die ersten beiden Dateien registrieren die Custom Resource Definitions `Keycloak` und
`KeycloakRealmImport`. Die dritte enthält ServiceAccount, Rollen und das Deployment des Operators.

### Schritt 1.3: Operator prüfen

```bash
kubectl -n keycloak get pods
kubectl api-resources --api-group=k8s.keycloak.org
```

Der Pod `keycloak-operator-…` steht auf `Running`, die zweite Ausgabe listet `keycloaks` und
`keycloakrealmimports`.

> **Konzept: Operator** - Ein Operator ist ein Controller, der eine Custom Resource
> beobachtet und daraus Standard-Ressourcen (StatefulSet, Service, Secret) erzeugt.
> Die CR beschreibt den Soll-Zustand; der Operator stellt ihn her und hält ihn.

---

## Teil 2: PostgreSQL deployen

### Schritt 2.1: Secret, Service und StatefulSet anwenden

```bash
kubectl apply -f manifests/01-postgres.yaml
kubectl -n keycloak get pods,pvc
```

Der Pod `postgres-0` ist nach kurzer Zeit `Running`, der PersistentVolumeClaim `data-postgres-0`
steht auf `Bound`.

### Schritt 2.2: Manifest lesen

Öffne `manifests/01-postgres.yaml` und finde:

| Ressource | Zweck |
| --- | --- |
| `Secret postgres-credentials` | Benutzername und Passwort; die Keycloak-CR liest sie später |
| `Service postgres` | Headless Service, DNS-Name `postgres` im Namespace |
| `StatefulSet postgres` | Ein Pod mit stabilem Namen und eigenem Volume |
| `volumeClaimTemplates` | Legt pro Pod einen PVC an, der Pod-Neustarts überlebt |

> **Konzept: StatefulSet** - Anders als ein Deployment bekommt jeder Pod einen stabilen
> Namen (`postgres-0`) und ein fest zugeordnetes Volume. Nach einem Neustart findet der
> Pod seine Daten wieder.

---

## Teil 3: Keycloak über die Custom Resource deployen

### Schritt 3.1: Die Keycloak-CR lesen

Öffne `manifests/02-keycloak.yaml`:

| Feld | Wert | Bedeutung |
| --- | --- | --- |
| `instances` | `1` | Anzahl der Keycloak-Pods |
| `db.host` | `postgres` | DNS-Name des Postgres-Service |
| `db.usernameSecret` / `passwordSecret` | `postgres-credentials` | Zugangsdaten aus dem Secret |
| `hostname.hostname` | `https://keycloak.mustertech.test` | Öffentliche URL für Redirects und Token-Issuer |
| `http.httpEnabled` | `true` | HTTP im Cluster; TLS terminiert der Ingress |
| `proxy.headers` | `xforwarded` | Keycloak vertraut `X-Forwarded-Proto` und `X-Forwarded-Host` vom Ingress |
| `ingress.enabled` | `false` | Der Ingress wird in Teil 4 selbst angelegt |
| `additionalOptions` | `metrics-enabled` | Jede `kc.sh`-Option lässt sich hier durchreichen |

Ein falscher `hostname` ist der häufigste Fehler in diesem Setup. Keycloak schickt den Browser
dann auf eine interne Adresse, die von außen nicht erreichbar ist.

### Schritt 3.2: CR anwenden

```bash
kubectl apply -f manifests/02-keycloak.yaml
kubectl -n keycloak get pods -w
```

Der Operator legt das StatefulSet `keycloak` an, der Pod `keycloak-0` startet. Beende die
Beobachtung mit `Ctrl+C`, sobald der Pod `1/1 Running` zeigt (ca. 60-90 Sekunden).

```bash
kubectl -n keycloak wait --for=condition=Ready keycloak/keycloak --timeout=300s
```

### Schritt 3.3: Erzeugte Ressourcen ansehen

```bash
kubectl -n keycloak get statefulset,service,secret
```

| Ressource | Von wem angelegt |
| --- | --- |
| `statefulset.apps/keycloak` | Operator, aus der CR |
| `service/keycloak-service` | Operator, Port 8080 für den Ingress |
| `service/keycloak-discovery` | Operator, Headless Service für die JGroups-Cluster-Bildung |
| `secret/keycloak-initial-admin` | Operator, temporärer Admin für den ersten Login |

### Schritt 3.4: Admin-Zugangsdaten auslesen

```bash
kubectl -n keycloak get secret keycloak-initial-admin -o jsonpath='{.data.username}' | base64 -d; echo
kubectl -n keycloak get secret keycloak-initial-admin -o jsonpath='{.data.password}' | base64 -d; echo
```

Notiere beide Werte. Der Benutzer ist ein temporärer Bootstrap-Admin; Keycloak blendet nach
dem Login einen Hinweis ein, einen dauerhaften Admin anzulegen.

---

## Teil 4: Ingress und TLS

### Schritt 4.1: Selbstsigniertes Zertifikat erzeugen

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=keycloak.mustertech.test" \
  -addext "subjectAltName=DNS:keycloak.mustertech.test"
kubectl -n keycloak create secret tls keycloak-tls --cert=tls.crt --key=tls.key
```

In Produktion übernimmt cert-manager diesen Schritt und erneuert das Zertifikat automatisch.

### Schritt 4.2: Ingress anwenden

```bash
kubectl apply -f manifests/03-ingress.yaml
kubectl -n keycloak get ingress
```

Der Ingress terminiert TLS mit dem Secret `keycloak-tls` und leitet HTTP an `keycloak-service:8080`
weiter. Der nginx-Controller setzt dabei `X-Forwarded-Proto: https`; nur deshalb erzeugt Keycloak
trotz HTTP im Cluster `https://`-URLs.

### Schritt 4.3: Hostnamen auflösen

Der Weg zum Ingress hängt vom Betriebssystem ab:

| System | Befehl | Eintrag in der Hosts-Datei |
| --- | --- | --- |
| macOS, Windows | `minikube tunnel` in einem zweiten Terminal laufen lassen | `127.0.0.1 keycloak.mustertech.test` |
| Linux | `minikube ip` | `<ausgegebene IP> keycloak.mustertech.test` |

Hosts-Datei: `/etc/hosts` (Linux, macOS) oder `C:\Windows\System32\drivers\etc\hosts` (Windows).
`minikube tunnel` fragt nach dem Administrator-Passwort, weil es die Ports 80 und 443 belegt.

### Schritt 4.4: Admin-Konsole öffnen

Öffne `https://keycloak.mustertech.test/admin/` und bestätige die Zertifikatswarnung.
Melde dich mit den Werten aus Schritt 3.4 an.

Keycloak zeigt oben den Hinweis zum temporären Admin. Lege unter **Users** im Realm `master`
einen dauerhaften Admin an und weise ihm die Realm-Rolle `admin` zu.

---

## Teil 5: Realm importieren

### Schritt 5.1: KeycloakRealmImport anwenden

```bash
kubectl apply -f manifests/04-realm-import.yaml
kubectl -n keycloak get pods -w
```

Der Operator startet einen Job `mustertech-…`, der den Realm in die Datenbank schreibt. Danach
startet er die Keycloak-Pods neu, damit keine veralteten Caches bleiben. Beende die Beobachtung,
sobald `keycloak-0` wieder `1/1 Running` zeigt.

```bash
kubectl -n keycloak wait --for=condition=Done keycloakrealmimport/mustertech --timeout=300s
```

### Schritt 5.2: Realm prüfen

Wechsle in der Admin-Konsole in den Realm **mustertech**. Unter **Users** stehen `hans.mueller`,
`anna.schmidt` und `max.admin`, unter **Clients** die vier Clients des Mitarbeiterportals.

Melde dich unter `https://keycloak.mustertech.test/realms/mustertech/account/` als `hans.mueller`
mit `Muster1234!` an.

> **Konzept: Realm als Ressource** - Die Realm-Konfiguration liegt damit als YAML im
> Git-Repository und wird wie jedes andere Manifest ausgerollt. Der Import läuft einmal;
> Änderungen an der CR führen zu keinem erneuten Import, solange der Realm existiert.

---

## Teil 6: Skalieren

### Schritt 6.1: Zweite Instanz starten

Setze in `manifests/02-keycloak.yaml` das Feld `instances` auf `2` und wende das Manifest erneut an:

```bash
kubectl apply -f manifests/02-keycloak.yaml
kubectl -n keycloak get pods -w
```

### Schritt 6.2: Cluster-Bildung beobachten

```bash
kubectl -n keycloak logs keycloak-1 | grep "cluster view"
```

Die Zeile `Received new cluster view for channel ISPN: [keycloak-0-…|1] (2) [keycloak-0-…, keycloak-1-…]`
zeigt, dass beide Pods einen Infinispan-Cluster gebildet haben. Die Mitglieder haben sich über den
Headless Service `keycloak-discovery` per DNS gefunden; der Operator setzt dafür
`cache-stack=kubernetes` und `jgroups.dns.query` automatisch.

### Schritt 6.3: Ausfall simulieren

Bleibe im Account-Portal als `hans.mueller` angemeldet und lösche den ersten Pod:

```bash
kubectl -n keycloak delete pod keycloak-0
```

Lade das Account-Portal neu. Die Sitzung bleibt bestehen: Keycloak 26 speichert User-Sessions in
der Datenbank, der zweite Pod bedient die Anfrage. Das StatefulSet startet `keycloak-0` von selbst
wieder.

---

## Teil 7: Health und Metriken

### Schritt 7.1: Probes im Pod ansehen

```bash
kubectl -n keycloak describe pod keycloak-0 | grep -E "Liveness|Readiness|Startup"
```

Der Operator konfiguriert alle drei Probes auf Port `9000`, dem Management-Port. Kubernetes
nimmt einen Pod erst in den Service auf, wenn `/health/ready` antwortet.

### Schritt 7.2: Endpoints abfragen

```bash
kubectl -n keycloak port-forward keycloak-0 9000:9000
```

In einem zweiten Terminal:

```bash
curl http://localhost:9000/health/ready
curl http://localhost:9000/health/live
curl -s http://localhost:9000/metrics | grep -E "^keycloak_|^jvm_memory_used"
```

`/health/ready` prüft die Datenbankverbindung mit; `/metrics` liefert das Prometheus-Format. Der
Management-Port ist nicht im Ingress freigegeben und damit von außen nicht erreichbar.

---

## Bonus: Konfigurationsänderung ausrollen

Ergänze in `manifests/02-keycloak.yaml` unter `additionalOptions`:

```yaml
    - name: log-level
      value: "INFO,org.infinispan:DEBUG"
```

```bash
kubectl apply -f manifests/02-keycloak.yaml
kubectl -n keycloak get pods -w
```

Der Operator tauscht die Pods nacheinander aus; mindestens einer bleibt erreichbar. Denselben Weg
nimmt ein Versions-Upgrade: neues Image in der CR, der Operator prüft die Kompatibilität und
entscheidet zwischen Rolling Update und Neustart.

---

## Aufräumen

```bash
minikube delete
rm tls.key tls.crt
```

`minikube delete` entfernt Cluster und Volumes. Der Eintrag in der Hosts-Datei kann bleiben.

---

## Zusammenfassung

Du hast erfolgreich:

- [x] Den Keycloak Operator installiert und die CRDs kennengelernt
- [x] Keycloak über eine `Keycloak`-CR mit externer Datenbank deployt
- [x] TLS am Ingress terminiert und den Hostnamen gesetzt
- [x] Den Realm `mustertech` als `KeycloakRealmImport` ausgerollt
- [x] Auf zwei Instanzen skaliert und den Infinispan-Cluster beobachtet
- [x] Health-Endpoints und Metriken über den Management-Port abgefragt

---

## Troubleshooting

Siehe zentrales Troubleshooting: [Kubernetes / minikube](../TROUBLESHOOTING.md#kubernetes--minikube)

---

## Weiterführende Ressourcen

- [Keycloak Operator Installation](https://www.keycloak.org/operator/installation)
- [Keycloak Operator: Basic Deployment](https://www.keycloak.org/operator/basic-deployment)
- [Keycloak Operator: Realm Import](https://www.keycloak.org/operator/realm-import)
- [Keycloak: Configuring distributed caches](https://www.keycloak.org/server/caching)
- [minikube: Ingress DNS](https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/)
