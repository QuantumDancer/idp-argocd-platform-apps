# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick instructions

- Use the context7 MCP to search for up-to-date documentation.
- Use rm -f to delete files (on Fedora, rm is aliased : rm='nocorrect rm -i')
- Do not set limits on cpu, as this is generally not recommended. Only set requests for cpu and memory and limits for memory.

## Repository Overview

This repository contains an ArgoCD-based platform using the App-of-Apps pattern for Kubernetes cluster management. It uses GitOps principles to declaratively manage infrastructure and application deployments.

## Architecture

**Sync Waves**:
Applications use `argocd.argoproj.io/sync-wave` annotations to control deployment order.
A lower wave syncs and becomes healthy before higher waves start. Apps at the same wave have no ordering guarantee.

```
Wave -1: gateway-api-crds                    (CRDs only, no deps)
Wave  0: external-secrets-operator, kyverno,  (no in-repo CRD deps)
         loki, longhorn
Wave  1: networking-config, argocd-config,    (depend on wave -1/0 CRDs)
         crossplane, kube-prometheus-stack,
         grafana-operator
Wave  2: cert-manager, cloudnative-pg,        (depend on wave 1 CRDs)
         k8s-monitoring, platform-resources,
         external-dns
Wave  3: grafana-database                     (depends on cloudnative-pg)
Wave  4: grafana                              (depends on grafana-operator + grafana-database)
Wave  5: grafana-dashboards                   (depends on grafana + kube-prometheus-stack)
```

**CRD Dependency Graph** (provider → consumer):

```
gateway-api-crds ──┬──> networking-config (Gateway)
                   ├──> longhorn (HTTPRoute)
                   ├──> argocd-config (HTTPRoute, GRPCRoute)
                   ├──> kube-prometheus-stack (HTTPRoute)
                   └──> grafana (HTTPRoute)

external-secrets-operator ──┬──> networking-config (ExternalSecret, when bgp.enabled)
                            ├──> cert-manager (ExternalSecret)
                            ├──> external-dns (ExternalSecret)
                            ├──> grafana (ExternalSecret)
                            └──> grafana-database (ExternalSecret)

kube-prometheus-stack ──┬──> cert-manager (PodMonitor)
                        ├──> cloudnative-pg (PodMonitor)
                        ├──> k8s-monitoring (ServiceMonitor/PodMonitor/PrometheusRule)
                        └──> grafana-dashboards (PrometheusRule)

grafana-operator ──┬──> cloudnative-pg (GrafanaDashboard)
                   ├──> grafana (Grafana, GrafanaDatasource)
                   └──> grafana-dashboards (GrafanaDashboard)

crossplane ──> platform-resources (XRD, Composition)
cloudnative-pg ──> grafana-database (CNPG Cluster)
grafana-database ──> grafana (runtime dependency)
grafana ──> grafana-dashboards (dashboard instance selector)
```

**Chart Structure**:

- Custom Helm charts in `charts/` directory
- Charts may wrap upstream charts as dependencies (e.g., external-secrets-operator wraps the official external-secrets chart)
- Charts contain additional custom resources (ServiceAccounts, ClusterSecretStores, RBAC, etc.)

## Key Commands

**Update Helm chart dependencies**:

```bash
helm dependency update charts/<chart-name>
```

**Template and validate charts locally**:

```bash
helm template <release-name> charts/<chart-name> --values charts/<chart-name>/values.yaml
helm lint charts/<chart-name>
```

**Access ArgoCD UI locally**:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# UI available at https://localhost:8080
```

**Retrieve ArgoCD admin password**:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

**Validate Kubernetes manifests**:

```bash
kubectl apply --dry-run=client -f <file>
kubectl apply --dry-run=server -f <file>
```

## External Dependencies

**GitLab Repository**:

- Uses GitLab Deploy Tokens for authentication
- Repository URL: https://gitlab.home.rottlr.de/idp/platform/idp-argocd-platform-apps.git

**Gateway API**:

- ArgoCD exposed via Gateway API (HTTPRoute and GRPCRoute)
- Expects external Gateway named "external" in "gateway" namespace
- TLS terminated at Gateway level (ArgoCD configured with `server.insecure: true`)

**HashiCorp Vault**:

- External Secrets Operator configured to use Vault at https://vault.home.rottlr.de:8200
- Uses Kubernetes auth with role "external-secrets-operator"
- Vault path: "secrets" (KV v2 engine)

## Important Patterns

**Adding New Platform Applications**:

1. Create Helm chart in `charts/<app-name>/` with Chart.yaml and values.yaml
2. Create ArgoCD Application manifest in `apps/<app-name>.yaml` pointing to the chart path
3. Use sync waves if deployment order matters
4. The root app will automatically detect and deploy the new application

**Helm Chart with Upstream Dependency**:
See `charts/external-secrets-operator/` as reference:

- Chart.yaml declares upstream chart as dependency
- values.yaml passes configuration to upstream chart (prefixed with subchart name)
- templates/ contains additional custom resources
- Run `helm dependency update` to download dependencies to `charts/` subdirectory

**Gateway API Routes**:
See `charts/argocd-config/templates/` for HTTPRoute and GRPCRoute examples. Routes reference Gateway via parentRefs and configure hostname-based routing.

## Monitoring Mixins Workflow

This repository uses [monitoring mixins](https://monitoring.mixins.dev/) to generate Grafana dashboards and Prometheus rules from jsonnet source code. Mixins are customized to work with Grafana Alloy's metric labeling scheme.

**Architecture**:

- `mixins/<component>/`: Jsonnet source code with customizations
- `charts/grafana-dashboards/`: Helm chart that deploys compiled dashboards and rules
- Compiled artifacts (JSON/YAML) are committed to Git for GitOps workflow

**Directory Structure**:

```
mixins/
└── kubernetes/
    ├── jsonnetfile.json      # Dependencies (via jsonnet-bundler)
    ├── jsonnetfile.lock.json # Dependency lock file (committed)
    ├── mixin.libsonnet       # Customization layer for Alloy labels
    ├── Makefile             # Compilation commands
    ├── vendor/              # Downloaded dependencies (gitignored)
    └── README.md

charts/grafana-dashboards/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── kubernetes-dashboards.yaml  # Creates ConfigMaps + GrafanaDashboard CRs
│   ├── kubernetes-alerts.yaml      # Creates PrometheusRule CR for alerts
│   └── kubernetes-rules.yaml       # Creates PrometheusRule CR for recording rules
├── dashboards/
│   └── kubernetes/                 # Generated JSON dashboards (committed)
└── rules/
    └── kubernetes/                 # Generated YAML rules (committed)
```

**Prerequisites**:

Install jsonnet tooling (required for compilation):

```bash
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/monitoring-mixins/mixtool/cmd/mixtool@latest
export PATH=$PATH:$(go env GOPATH)/bin
```

**Compiling Mixins**:

```bash
# Navigate to mixin directory
cd mixins/kubernetes

# First time: install dependencies
jb install

# Compile dashboards, alerts, and rules
make all

# Or compile individually
make dashboards  # Generates JSON dashboards
make alerts      # Generates alert rules YAML
make rules       # Generates recording rules YAML

# Validate mixin
make lint
```

**Customizing Mixins**:

Edit `mixin.libsonnet` to override selectors and configuration:

```jsonnet
local kubernetes = (import 'kubernetes-mixin/mixin.libsonnet');

kubernetes {
  _config+:: {
    // Override label selectors for Alloy
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',

    // Adjust alert thresholds
    cpuThrottlingPercent: 30,
  },
}
```

After editing, run `make all` to regenerate artifacts.

**Deploying via ArgoCD**:

Compiled artifacts are automatically deployed via the `grafana-dashboards` ArgoCD Application (sync wave 5):

- Dashboards → ConfigMaps → GrafanaDashboard CRs (Grafana Operator provisions them)
- Rules/Alerts → PrometheusRule CRs (Prometheus Operator loads them)

**Updating Dashboards**:

```bash
# 1. Modify customization
cd mixins/kubernetes
vim mixin.libsonnet

# 2. Recompile
make all

# 3. Commit changes
git add ../../charts/grafana-dashboards/dashboards/kubernetes/
git add ../../charts/grafana-dashboards/rules/kubernetes/
git commit -m "Update kubernetes-mixin configuration"

# 4. Push to trigger ArgoCD sync
git push
```

**Adding New Mixins**:

To add a new component (e.g., argocd, cert-manager):

```bash
# 1. Create mixin directory
mkdir -p mixins/argocd
cd mixins/argocd

# 2. Create jsonnetfile.json
cat > jsonnetfile.json <<EOF
{
  "version": 1,
  "dependencies": [
    {
      "source": {
        "git": {
          "remote": "https://github.com/example/argocd-mixin.git",
          "subdir": ""
        }
      },
      "version": "main"
    }
  ],
  "legacyImports": true
}
EOF

# 3. Create mixin.libsonnet with customizations
# 4. Copy Makefile from mixins/kubernetes/
# 5. Run make install && make all
# 6. Create templates in charts/grafana-dashboards/templates/
# 7. Commit and push
```

**Key Notes**:

- Generated artifacts (JSON/YAML) are committed to Git for reproducibility
- Mixins are customized for Grafana Alloy's `integrations/*` job label prefix
- The `vendor/` directory is gitignored (regenerated via `jb install`)
- See individual mixin README.md files for component-specific documentation

## Repository Configuration

**Git Repository Structure**:

- Main branch for production deployments
- ArgoCD tracks `main` branch with automated sync, prune, and self-heal enabled

**Ignored Files**:

- `charts/*/charts/*.tgz`: Downloaded Helm chart dependencies
