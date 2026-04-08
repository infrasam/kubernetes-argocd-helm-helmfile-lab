# Kubernetes GitOps Platform

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white)
![Helmfile](https://img.shields.io/badge/Helmfile-326CE5?style=for-the-badge&logo=helm&logoColor=white)
![Vault](https://img.shields.io/badge/Vault-FFEC6E?style=for-the-badge&logo=vault&logoColor=black)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)

A fully automated **GitOps platform** for Kubernetes, built on **ArgoCD**, **Helmfile**, and **Helm**. All infrastructure is declared as code, with automated dependency updates, centralized secret management via **HashiCorp Vault**, and a complete observability stack. The platform supports **multi-cluster** deployments through environment-based configuration.

---

## Architecture Overview

```mermaid
flowchart LR
    subgraph automation["⚙ Automated Pipeline"]
        renovate["🔄 Renovate"]
        jenkins["🔧 Jenkins"]
    end

    subgraph repo["📦 GitHub Repository"]
        helmfile["📝 Helmfile Templates"]
        manifests["📋 Generated Manifests"]
    end

    subgraph cluster["☸ Kubernetes Cluster"]
        argocd["🚀 ArgoCD"]

        subgraph platform[" "]
            direction LR
            networking["🌐 Networking<br/><code>Contour · MetalLB<br/>External-DNS · Istio</code>"]
            secrets["🔐 Secrets<br/><code>Vault HA<br/>External-Secrets<br/>Cert-Manager</code>"]
            observability["📊 Observability<br/><code>Prometheus · Grafana<br/>Loki · Promtail</code>"]
            security["🛡 Security<br/><code>Falco · Trivy<br/>Kubescape</code>"]
        end
    end

    renovate -.->|"Version bump PR"| helmfile
    jenkins -.->|"Compiles on PR"| helmfile
    helmfile ==>|"manifest.lock.yaml"| manifests
    manifests ==>|"Git sync"| argocd
    argocd --> networking
    argocd --> secrets
    argocd --> observability
    argocd --> security

    style automation fill:#161b22,stroke:#f0883e,color:#f0883e,stroke-width:2px
    style repo fill:#161b22,stroke:#58a6ff,color:#58a6ff,stroke-width:2px
    style cluster fill:#161b22,stroke:#3fb950,color:#3fb950,stroke-width:2px
    style platform fill:transparent,stroke:none
    style networking fill:#1a2332,stroke:#58a6ff,color:#adbac7,stroke-width:1px
    style secrets fill:#2a1f1f,stroke:#f47067,color:#adbac7,stroke-width:1px
    style observability fill:#1f2a1f,stroke:#3fb950,color:#adbac7,stroke-width:1px
    style security fill:#2a2a1f,stroke:#d29922,color:#adbac7,stroke-width:1px
```

---

## GitOps Workflow

The platform uses a **pre-rendered manifest pattern** — Helmfile templates are compiled into static YAML before ArgoCD deploys them. This decouples templating from deployment and provides a clear audit trail in Git.

### Initial Deployment (manual)

A new application is added by creating a Helmfile release under `releases/`, defining its chart version and enabling it in the environment config (`bases/environments/`), then generating manifests locally.

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant HF as Helmfile
    participant GH as GitHub
    participant A as ArgoCD
    participant K as Kubernetes

    Dev->>HF: Creates release in releases/
    Dev->>HF: Adds chart version & installed: true in bases/
    Dev->>HF: Runs manifest-generate.sh
    HF->>HF: Templates helmfile.yaml + values.yaml
    HF->>GH: Commits manifest.lock.yaml to generated/
    GH->>GH: Push / PR merged to main
    A->>GH: ApplicationSet discovers new directory
    A->>K: Creates namespace & syncs manifests
    K-->>A: Reports sync status
```

### Automated Updates (Renovate + Jenkins)

Once deployed, chart versions are kept up to date automatically.

```mermaid
sequenceDiagram
    participant R as Renovate
    participant GH as GitHub
    participant J as Jenkins
    participant HF as Helmfile
    participant A as ArgoCD
    participant K as Kubernetes

    R->>GH: Detects new chart version
    R->>GH: Creates PR with version bump
    J->>GH: Detects open Renovate PR
    J->>HF: Runs manifest-generate.sh
    HF->>GH: Commits regenerated manifests
    actor Dev as Developer
    Dev->>GH: Reviews & approves PR
    GH->>GH: PR merged to main
    A->>GH: Detects changes in generated/
    A->>K: Syncs updated manifests
    K-->>A: Reports sync status
```

**How it works:**

1. A new release is added under `releases/` and manifests are generated locally via `manifest-generate.sh`
2. ArgoCD **ApplicationSet** auto-discovers the new `generated/<cluster>/<app>/` directory and deploys it
3. Going forward, **Renovate** scans Helm registries hourly and creates version bump PRs
4. **Jenkins** picks up Renovate PRs, regenerates manifests, and commits them back to the branch
5. A developer **reviews and approves** the PR before merge
6. After merge, **ArgoCD** syncs the updated manifests to the cluster

---

## Infrastructure Components

### GitOps & Delivery

| Component | Description |
|-----------|-------------|
| **ArgoCD** | GitOps controller using ApplicationSet for dynamic app discovery from `generated/` directories |
| **Jenkins** | Runs the manifest regeneration pipeline when Renovate creates dependency update PRs |
| **Renovate** | Scans Helm chart registries hourly and creates automated version bump PRs |

### Networking & Ingress

| Component | Description |
|-----------|-------------|
| **Contour** | Envoy-based ingress controller handling HTTPS routing for all exposed services |
| **MetalLB** | Bare-metal load balancer providing external IPs via L2 advertisement |
| **External-DNS** | Syncs Kubernetes ingress records to Cloudflare DNS automatically |
| **Istio** | Service mesh in ambient mode providing mTLS and traffic management without sidecars |

### Security & Secrets

| Component | Description |
|-----------|-------------|
| **Vault** | HA secret store (3-replica Raft cluster) — structure and configuration owned by Terraform in a separate repository |
| **External-Secrets** | Operator syncing secrets from Vault into Kubernetes via ClusterSecretStore |
| **Cert-Manager** | Automated TLS certificates via Let's Encrypt with Cloudflare DNS-01 validation |
| **Falco** | Runtime threat detection and security monitoring |
| **Trivy** | Container image vulnerability scanning |
| **Kubescape** | Kubernetes security posture and compliance scanning |

### Observability

| Component | Description |
|-----------|-------------|
| **Prometheus + Grafana** | Metrics collection and visualization via kube-prometheus-stack |
| **Loki + Promtail** | Log aggregation with Promtail collecting logs from all nodes |

---

## Repository Structure

```
.
├── bases/                          # Shared configuration
│   ├── environments/               # Per-cluster settings and chart versions
│   │   ├── cl-infrasam-prod.yaml   #   Production cluster config
│   │   └── cl-infrasam-test.yaml   #   Test cluster config
│   ├── helmDefaults.yaml           # Global Helm behavior (atomic, timeout)
│   └── environments.yaml           # Environment-to-cluster mapping
│
├── releases/                       # One directory per application
│   ├── argocd/                     #   Includes ApplicationSet & AppProject definitions
│   ├── vault/                      #   HA Vault with Raft storage
│   ├── external-secrets/           #   ClusterSecretStore for Vault integration
│   ├── kube-prometheus-stack/      #   Prometheus, Grafana, Alertmanager
│   ├── istio/                      #   Base, Istiod, CNI, Ztunnel
│   └── .../                        #   Each release has helmfile.yaml + values.yaml
│
├── charts/                         # Reusable local Helm charts
│   ├── es-secrets/                 #   ExternalSecret template (used by 6+ releases)
│   └── grafana-dashboards/         #   Grafana dashboard provisioning
│
├── generated/                      # Pre-rendered manifests (ArgoCD reads from here)
│   └── cl-infrasam-prod/           #   One manifest.lock.yaml per application
│
├── pipelines/                      # CI/CD pipeline definitions
│   └── Jenkinsfile.renovate        #   Manifest regeneration for Renovate PRs
│
└── manifest-generate.sh            # Helmfile → manifest compilation script
```

---

## Secret Management

All application credentials are managed through **Vault** and delivered to pods via **External-Secrets Operator**. No secrets are stored in Git.

**Terraform** (in a separate repository) owns the Vault structure — it deploys the secret engine mounts, policies, auth methods, and the folder hierarchy for each application. The actual secret values are then populated manually.

```mermaid
flowchart LR
    TF["Terraform<br/><i>Deploys structure<br/>& folder hierarchy</i>"]
    Admin["Admin<br/><i>Populates secret<br/>values manually</i>"]
    V["Vault<br/><i>HA Raft Cluster</i>"]
    CSS["ClusterSecretStore<br/><i>K8s Auth → Vault</i>"]
    ES["ExternalSecret<br/><i>Per-application</i>"]
    KS["Kubernetes Secret"]
    Pod["Pod"]

    TF -->|"Engines, policies,<br/>auth, folders"| V
    Admin -->|"Writes secret<br/>values"| V
    V -->|"KV v2 API"| CSS
    CSS --> ES
    ES -->|"Creates & refreshes<br/>every 1h"| KS
    KS -->|"Mounted as env/volume"| Pod

    style TF fill:#7b42bc,stroke:#9a6dd7,color:#fff
    style Admin fill:#1f6feb,stroke:#58a6ff,color:#fff
    style V fill:#ffec6e,stroke:#d4c44a,color:#000
    style CSS fill:#2d333b,stroke:#444c56,color:#adbac7
    style ES fill:#2d333b,stroke:#444c56,color:#adbac7
    style KS fill:#2d333b,stroke:#444c56,color:#adbac7
    style Pod fill:#326ce5,stroke:#4a8af4,color:#fff
```

Applications using Vault secrets include Jenkins, Renovate, Cert-Manager, External-DNS, and Grafana — each with dedicated ExternalSecret resources created via a shared `es-secrets` Helm chart template.

---

## Multi-Cluster Support

The platform is designed for multi-cluster operations. Each cluster gets its own environment configuration, generated manifests, and ArgoCD AppProject — following the same pattern. Test clusters can be registered as remote targets in the production cluster's ArgoCD, allowing infrastructure components to be pushed out to guest clusters from a single control plane.

```mermaid
flowchart TB
    subgraph config["Environment Configuration"]
        prod_env["cl-infrasam-prod.yaml<br/><i>Chart versions & feature flags</i>"]
        test_env["cl-infrasam-test.yaml<br/><i>Same structure, own versions</i>"]
    end

    subgraph generated["Generated Manifests"]
        prod_gen["generated/cl-infrasam-prod/*"]
        test_gen["generated/cl-infrasam-test/*"]
    end

    subgraph argocd["ArgoCD (Production Cluster)"]
        prod_appset["ApplicationSet<br/><i>cl-infrasam-prod</i>"]
        test_appset["ApplicationSet<br/><i>cl-infrasam-test</i>"]
    end

    prod_cluster["☸ Production Cluster"]
    test_cluster["☸ Test Cluster<br/><i>Registered as remote target</i>"]

    prod_env --> prod_gen
    test_env --> test_gen
    prod_gen --> prod_appset
    test_gen --> test_appset
    prod_appset -->|"Deploys locally"| prod_cluster
    test_appset -->|"Deploys remotely"| test_cluster

    style config fill:#2d333b,stroke:#444c56,color:#adbac7
    style generated fill:#1c2128,stroke:#444c56,color:#adbac7
    style argocd fill:#1a2332,stroke:#ef7b4d,color:#adbac7
    style prod_cluster fill:#161b22,stroke:#3fb950,color:#3fb950,stroke-width:2px
    style test_cluster fill:#161b22,stroke:#58a6ff,color:#58a6ff,stroke-width:2px
```

**Adding a new cluster** requires only:
1. A new environment file in `bases/environments/`
2. A new ArgoCD AppProject and ApplicationSet entry
3. Registering the cluster as a remote target in ArgoCD
4. Running `manifest-generate.sh` for the new environment

---

## Key Design Decisions

- **Pre-rendered manifests** — Helmfile compiles templates into static YAML (`manifest.lock.yaml`) committed to Git, giving ArgoCD a clean source of truth and full diff visibility
- **ApplicationSet pattern** — A single ApplicationSet per cluster auto-discovers applications from the `generated/` directory structure, eliminating manual Application creation
- **Multi-cluster via environment files** — Each cluster is a separate Helmfile environment with its own chart versions and feature flags, enabling independent lifecycle management
- **Reusable ExternalSecret chart** — A shared `es-secrets` Helm chart templates ExternalSecret resources across all applications, ensuring consistent Vault integration
- **Automated dependency lifecycle** — Renovate detects updates, Jenkins regenerates manifests, and ArgoCD deploys — reducing manual maintenance to PR review and merge
