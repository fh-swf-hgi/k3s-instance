# K3s Single-Node GitOps Instance

Ein vollständig reproduzierbares Single-Node-Kubernetes-Setup auf Basis von:

- Ubuntu 24.04
- K3s
- Argo CD
- GitOps
- ingress-nginx
- Ansible
- SSH
- Makefile

Ziel des Projekts ist eine minimalistische, aber produktionsnahe Kubernetes-Plattform, die sich:

- schnell reproduzieren lässt
- vollständig deklarativ verwalten lässt
- GitOps-fähig ist
- leicht um weitere Anwendungen erweitert werden kann
- als Basis für AI-/Cloud-/GPU-Workloads eignet

---

# Architektur

## Gesamtübersicht

```text
┌────────────────────────────────────┐
│ Developer Machine                  │
│                                    │
│ git push                           │
│ kubectl                            │
│ ansible                            │
│ make                               │
└────────────────────────────────────┘
                 │
                 │ SSH
                 ▼
┌────────────────────────────────────┐
│ Ubuntu 24.04 Host                  │
│                                    │
│ K3s                                │
│ ├── Kubernetes API                 │
│ ├── containerd                     │
│ ├── local-path storage             │
│ └── CoreDNS                        │
│                                    │
│ ingress-nginx                      │
│ └── HTTP/HTTPS entrypoint          │
│                                    │
│ Argo CD                            │
│ ├── Watches Git repository         │
│ └── Deploys applications           │
│                                    │
│ Apps                               │
│ ├── nginx demo                     │
│ └── Langflow                       │
└────────────────────────────────────┘
```

---

# Zielsetzung

Dieses Repository implementiert folgende Grundidee:

```text
Fresh Ubuntu Server
→ SSH erreichbar
→ git clone
→ make bootstrap
→ make kubeconfig
→ make argocd-bootstrap
→ Git push deployt automatisch Anwendungen
```

---

# Verwendete Technologien

| Komponente | Zweck |
|---|---|
| Ubuntu 24.04 | Basisbetriebssystem |
| K3s | Lightweight Kubernetes |
| Argo CD | GitOps Deployment |
| ingress-nginx | HTTP/HTTPS Routing |
| Ansible | Provisionierung |
| Makefile | Vereinfachte Bedienung |
| GitHub | Single Source of Truth |
| containerd | Container Runtime |
| local-path-provisioner | Persistenter Storage |

---

# Repository-Struktur

```text
k3s-instance/
├── Makefile
├── bootstrap.sh
├── kubeconfig                 # lokal erzeugt, NICHT committen
├── ansible/
│   ├── inventory.ini          # lokal erzeugt, NICHT committen
│   ├── site.yml
│   └── reset.yml
├── argocd/
│   ├── demo-nginx.yaml
│   ├── ingress-nginx.yaml
│   └── langflow.yaml
└── apps/
    ├── demo-nginx/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── ingress-nginx/
    │   ├── install.yaml
    │   └── namespace.yaml
    └── langflow/
        ├── namespace.yaml
        ├── deployment.yaml
        ├── service.yaml
        ├── pvc.yaml
        └── ingress.yaml
```

---

# Voraussetzungen

## Zielhost

Der Zielhost benötigt:

- Ubuntu 24.04
- SSH-Zugriff
- sudo-Rechte
- Internetzugang

Beispiel:

```text
Hostname: myhost
User:     hgi
```

SSH-Test:

```bash
ssh gaming
```

---

# Lokale Voraussetzungen

Benötigte Tools auf dem lokalen Rechner:

macOS:

```bash
brew install kubectl
brew install ansible
brew install make
brew install git
```

Ubuntu/Debian:

```bash
sudo apt install ansible make git
```

---

# Bootstrap des Clusters

## Repository klonen

```bash
git clone https://github.com/fh-swf-hgi/k3s-instance.git
cd k3s-instance
```

---

## K3s installieren

```bash
make bootstrap
```

Dies installiert automatisch:

- K3s
- Kubernetes API
- containerd
- local-path storage
- systemd Services

---

## kubeconfig lokal exportieren

```bash
make kubeconfig
```

Dadurch entsteht lokal:

```text
./kubeconfig
```

Wichtig:

```text
NICHT committen.
```

---

## Cluster testen

```bash
make test
```

Erwartung:

```text
NAME     STATUS   ROLES           VERSION
gaming   Ready    control-plane   v1.35.x+k3s1
```

---

# Argo CD installieren

## Bootstrap

```bash
make argocd-bootstrap
```

Dies installiert:

- Namespace
- Argo CD
- Demo-App

---

# Argo CD überprüfen

```bash
KUBECONFIG=./kubeconfig kubectl get applications -n argocd
```

Beispiel:

```text
NAME            SYNC STATUS   HEALTH STATUS
demo-nginx      Synced        Healthy
ingress-nginx   Synced        Healthy
langflow        Synced        Healthy
```

---

# Argo CD Synchronisation

Ohne GitHub-Webhook erkennt Argo CD Änderungen nicht sofort, sondern pollt periodisch das Repository.

Manueller Refresh:

```bash
KUBECONFIG=./kubeconfig kubectl -n argocd annotate application langflow \
  argocd.argoproj.io/refresh=hard --overwrite
```

Optional kann das Reconciliation-Intervall angepasst werden.

---

# Argo CD Web UI

## Passwort abrufen

```bash
make argocd-password
```

---

## UI lokal öffnen

```bash
make argocd-ui
```

Browser:

```text
https://localhost:8080
```

User:

```text
admin
```

---

# GitOps Workflow

## Grundidee

Anwendungen werden NICHT direkt mit `kubectl apply` deployt.

Stattdessen:

```text
Git Commit
→ Git Push
→ Argo CD erkennt Änderung
→ Kubernetes wird automatisch synchronisiert
```

---

# Anwendungen hinzufügen

## Grundstruktur

Neue Anwendungen kommen nach:

```text
apps/<app-name>/
```

Beispiel:

```text
apps/langflow/
```

---

# Typische Kubernetes-Dateien

| Datei | Zweck |
|---|---|
| namespace.yaml | Namespace |
| deployment.yaml | Container |
| service.yaml | Netzwerkzugriff |
| pvc.yaml | Persistenter Storage |
| ingress.yaml | HTTP-Zugriff |

---

# Beispiel: Langflow

## Struktur

```text
apps/langflow/
├── namespace.yaml
├── deployment.yaml
├── service.yaml
├── pvc.yaml
└── ingress.yaml
```

---

# Argo-CD-Application erstellen

Datei:

```text
argocd/langflow.yaml
```

Beispiel:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: langflow
  namespace: argocd

spec:
  project: default

  source:
    repoURL: https://github.com/fh-swf-hgi/k3s-instance.git
    targetRevision: main
    path: apps/langflow

  destination:
    server: https://kubernetes.default.svc
    namespace: langflow

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
```

---

# Anwendung deployen

```bash
git add .
git commit -m "Add Langflow deployment"
git push
```

---

# Deployment überwachen

## Anwendungen

```bash
KUBECONFIG=./kubeconfig kubectl get applications -n argocd
```

---

## Pods

```bash
KUBECONFIG=./kubeconfig kubectl get pods -n langflow
```

Live-Watching:

```bash
KUBECONFIG=./kubeconfig kubectl get pods -n langflow -w
```

---

# Logs anzeigen

## Deployment-Logs

```bash
KUBECONFIG=./kubeconfig kubectl logs -n langflow deployment/langflow
```

---

## Vorheriger Crash

```bash
KUBECONFIG=./kubeconfig kubectl logs -n langflow deployment/langflow --previous
```

---

# Ressourcen anzeigen

```bash
KUBECONFIG=./kubeconfig kubectl get all -n langflow
```

---

# Persistenter Storage

K3s bringt standardmäßig lokalen Storage mit:

```text
local-path-provisioner
```

PVC prüfen:

```bash
KUBECONFIG=./kubeconfig kubectl get pvc -n langflow
```

Beispiel:

```text
NAME             STATUS   CAPACITY
langflow-data    Bound    10Gi
```

---

# Ingress

Dieses Setup verwendet `ingress-nginx` als Ingress-Controller.

Der Datenpfad ist:

```text
Browser
→ ingress-nginx NodePort
→ Kubernetes Service
→ Pod
```

Da in diesem K3s-Setup `servicelb` deaktiviert wurde, wird ingress-nginx über `NodePort` betrieben.

---

# ingress-nginx überprüfen

```bash
KUBECONFIG=./kubeconfig kubectl get application ingress-nginx -n argocd
KUBECONFIG=./kubeconfig kubectl get pods -n ingress-nginx
KUBECONFIG=./kubeconfig kubectl get svc -n ingress-nginx
```

Beispiel:

```text
NAME                                 TYPE       PORT(S)
ingress-nginx-controller             NodePort   80:30184/TCP,443:30325/TCP
```

---

# Ingress-Regeln prüfen

```bash
KUBECONFIG=./kubeconfig kubectl get ingress -A
```

Beispiel:

```text
NAMESPACE   NAME       CLASS   HOSTS   PORTS
langflow    langflow   nginx   *       80
```

Das `*` bedeutet:

```text
Kein fester Hostname erforderlich.
```

Dadurch ist Zugriff direkt per IP-Adresse möglich.

---

# Langflow im Browser öffnen

Beispiel:

```text
http://<host-ip>:30184
```

z.B.

```text
http://192.168.1.2:30184
```

---

# Port Forwarding

Alternativ ohne Ingress:

```bash
KUBECONFIG=./kubeconfig kubectl -n langflow port-forward svc/langflow 7860:80
```

Browser:

```text
http://localhost:7860
```

---

# Cluster zurücksetzen

## Vollständiger Reset

```bash
make reset
```

Dies entfernt:

- K3s
- Container
- Volumes
- Netzwerkinterfaces
- Kubernetes-Zustand

---

# Sicherheitsaspekte

## Niemals committen

```text
kubeconfig
ansible/inventory.ini
*.pem
*.key
.env
```

---

# .gitignore

```gitignore
kubeconfig
ansible/inventory.ini
*.pem
*.key
.env
```

---

# Wichtige kubectl-Kommandos

## Clusterstatus

```bash
kubectl get nodes
```

---

## Alle Namespaces

```bash
kubectl get ns
```

---

## Pods aller Namespaces

```bash
kubectl get pods -A
```

---

## Services

```bash
kubectl get svc -A
```

---

## Ingress-Ressourcen

```bash
kubectl get ingress -A
```

---

## Events

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

## Deployment beschreiben

```bash
kubectl describe deployment langflow -n langflow
```

---

## Pod beschreiben

```bash
kubectl describe pod <pod-name> -n langflow
```

---

# Typische Fehlerbilder

| Problem | Ursache |
|---|---|
| CrashLoopBackOff | Container startet nicht |
| ImagePullBackOff | Image nicht erreichbar |
| Pending | Storage/Scheduling Problem |
| Progressing | Deployment noch nicht ready |
| ErrImagePull | Registry/Tag falsch |

---

# Nächste sinnvolle Erweiterungen

## Infrastruktur

- cert-manager
- HTTPS
- DNS
- Tailscale
- Cloudflare Tunnel

---

## GitOps

- App-of-Apps Pattern
- Helm
- Kustomize
- SOPS/age
- External Secrets

---

## AI / GPU

- NVIDIA GPU Operator
- Ollama
- vLLM
- TGI
- Open WebUI

---

## Storage

- Longhorn
- OpenEBS
- Ceph
- Synology CSI

---

# Zielbild

Langfristig kann dieses Repository als Grundlage dienen für:

- AI-Plattformen
- Self-Service Kubernetes
- GPU Cluster
- Forschungsinfrastruktur
- Lehrplattformen
- GitOps-Labs
- Edge-Kubernetes
- HomeLab-Cluster
- Private AI Appliances

---

# Projektphilosophie

Dieses Repository verfolgt bewusst:

- einfache Architektur
- deklarative Infrastruktur
- reproduzierbare Setups
- Git als zentrale Wahrheit
- minimale manuelle Eingriffe
- kleine, nachvollziehbare Schritte

Ziel ist kein maximal komplexes Enterprise-Setup, sondern eine robuste, verständliche und erweiterbare Kubernetes-Basis.
