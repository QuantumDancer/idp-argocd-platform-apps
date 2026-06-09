# idp-argocd-platform-apps

This repository contains all core platform applications for my IDP reference implementation.
It uses the ArgoCD [app-of-apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) to declaratively manage the full platform lifecycle via GitOps.

It supports both my [homelab Kubernetes cluster](https://github.com/QuantumDancer/Homelab) and [AWS EKS](https://github.com/QuantumDancer/idp-terraform-aws-infra), with environment-specific configuration handled via Helm values overlays.

For the full project documentation (architecture, design decisions, self-service capabilities, and the broader repository landscape) see the **[idp](https://github.com/QuantumDancer/idp)** repo.

## What this repo deploys

### Networking & Ingress

- **gateway-api-crds** — Gateway API CRD installation (homelab only)
- **networking-config** — Cilium BGP, Gateway, and network policies (homelab only)
- **cert-manager** — TLS certificate management via Let's Encrypt
- **external-dns** — Automatic DNS record management

### GitOps & API

- **argocd-config** — ArgoCD configuration (SSO, routes, RBAC)
- **crossplane** — Crossplane control plane
- **crossplane-compositions** — Custom XRDs and compositions

### Secrets & Security

- **external-secrets-operator** — ESO + Vault ClusterSecretStore
- **kyverno** — Policy engine

### Storage

- **longhorn** — Distributed block storage (homelab only)
- **garage** — S3-compatible object storage (homelab only)
- **cloudnative-pg** — CloudNativePG operator

### Observability

- **kube-prometheus-stack** — Prometheus, Alertmanager, and core exporters
- **k8s-monitoring** — Grafana Alloy (metrics, logs, traces collection)
- **loki** — Log aggregation
- **tempo** — Distributed tracing
- **grafana-operator** — Grafana Operator for CRD-based dashboard management
- **grafana-database** — PostgreSQL database for Grafana (via CloudNativePG)
- **grafana** — Grafana instance with SSO
- **grafana-dashboards** — Grafana dashboards and Prometheus rules (compiled from monitoring mixins)
- **grafana-mcp** — Grafana MCP server for AI-assisted observability

### Eventing & Autoscaling

- **rabbitmq-operator** — RabbitMQ Cluster Operator
- **rabbitmq-topology-operator** — RabbitMQ Messaging Topology Operator
- **keda** — Kubernetes Event-Driven Autoscaling

### Identity (AWS only)

- **dex** — OIDC broker between IAM Identity Center (SAML) and Grafana/ArgoCD

### Platform & Workloads

- **priorityclass** — Cluster-wide PriorityClass definitions
- **backstage-database** — PostgreSQL database for Backstage (via CloudNativePG)
- **backstage-deployment** — Backstage portal deployment (optional)
- **user-apps** — Root ArgoCD application for developer-created workloads
