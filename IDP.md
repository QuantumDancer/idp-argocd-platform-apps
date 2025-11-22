# Ben's IDP

## Goal

1. Provide a reference architecture for an IDP.
   - Support for multiple application teams. RBAC for resource access.
   - Teams should be able to create a new application from a template via self-service.
2. Provide support for two environments: DEV and PROD
3. Support multiple languages and application types:
   - Backend: Java, Python
   - Frontend: React

## Available Resources

- Homelab
  - GitLab + GitLab Runner
  - HashiCorp Vault
- AWS (to save cost, only run during development, afterwards shut down completely)
  - EKS
  - Managed DBs

## Components

- Developer Control Plane
  - IDE: VSCode
  - Developer Portal: Backstage
  - Version Control: GitLab
  - Platform Source Code: Terraform (Bootstrap), Crossplane
- Integration & Delivery Plane
  - CI Pipeline: GitLab CI
  - Image Registry: GitLab Registry (maybe replace later with Harbor)
  - CD Tools:
    - Argo CD
    - Argo Rollouts
- Resource Plane
  - Compute:
    - Amazone EKS (Cost optimization: spot instances / EKS Fargate profiles)
    - Autoscaling: Karpenter, KEDA
  - Data
    - Amazon Aurora Serverless v2
    - CloudNativePG
    - S3
  - Networking
    - Cilium
    - Cloudflare
    - external-dns
    - cert-manager
  - Services
    - Elasticsearch
    - RabbitMQ/ActiveMQ
- Monitoring & Logging Plane
  - Observability:
    - Grafana LGTM (Loki, Grafana, Tempo, Mimir)
    - opencost
    - Kepptn Lifecycle Toolkit
- Security Plane
  - Secrets Management: Hashicorp Vault
  - Network based Security: Cilium, Falco
  - Policy: Kyverno
  - Scanning: Trivy

## Implementation Plan

### Phase 1: Core infrastructure

- [x] GitLab
- [x] HashiCorp Vault

### Phase 2: First IDP version

#### Core IDP

- [x] SCM + CI: GitLab + GitLab CI
- [x] Compute: Homelab. Included services (external-dns, cert-manager, Kyverno)
- [x] CD: ArgoCD
- [x] Data: CloudNativePG
- [x] API: Crossplane
- [x] Secrets:
  - [x] Vault
  - [x] ESO
- [x] Monitoring (subset of LGTM):
  - [x] Grafana
  - [x] Loki
  - [x] Prometheus
- [ ] Security:
  - [ ] Trivy in CI
  - [x] Kyverno

#### Platform features

- [ ] Kyverno Policies
- [ ] Crossplane XRDs

#### Workloads

- [ ] First example workloads

### Phase 3: Moving to the cloud

- Compute: EKS
  - AWS VPC CNI
  - Spot Instances (simulated base)
  - EKS Fargate profiles (simulate scaling)
- [ ] Networking:
  - [ ] external-dns
  - [ ] cert-manager
- [ ] Security
  - [ ] Kyverno

#### Platform features

- [ ] Extends XRDs with cloud versions / cloud specifc configuration

### Phase 4: Enhanced Capabilities

- Argo Rollouts (progressive delivery)
- Better observability
  - Full LGTM stack (Tempo, Mimir)
  - opencost
  - Keptn lifecycle toolkit
- Cilium (advanced networking)
- CloudNativePG for DEV + Aurora for PROD

### Phase 5: Advanced Platform Engineering

- Backstage (self-service portal)
- Falco (runtime security)
- Keptn Lifecycle Toolkit (DORA Metrics)
- Additional services (Elasticsearch, message queues)
- auto scaling
  - Karpenter
  - KEDA
