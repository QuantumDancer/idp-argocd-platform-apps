# Monitoring Mixins

This directory contains monitoring mixin configurations for generating Grafana dashboards and Prometheus rules from jsonnet source code.

## Overview

[Monitoring mixins](https://monitoring.mixins.dev/) are a set of Grafana dashboards, Prometheus recording rules, and alerts packaged together in a reusable and extensible bundle written in jsonnet.
They allow you to adopt community best practices and keep monitoring configuration as code.

**Key Components:**

- **Dashboards**: Pre-built Grafana dashboards for component monitoring
- **Alerts**: PrometheusRule alerts for critical conditions
- **Recording Rules**: Prometheus recording rules for efficient querying

All mixins in this directory are customized to work with **Grafana Alloy's metric labeling scheme**, which uses `job="integrations/*"` instead of standard Prometheus exporter labels.

## Directory Structure

Each component has its own directory following this structure:

```
mixins/<component>/
├── jsonnetfile.json         # Dependencies via jsonnet-bundler
├── jsonnetfile.lock.json    # Dependency lock file (committed)
├── mixin.libsonnet          # Customization layer (label selectors, config overrides)
├── Makefile                 # Compilation commands
├── vendor/                  # Downloaded dependencies (gitignored)
└── README.md                # Component-specific documentation
```

Generated files are placed in the grafana-dashboards chart:

```
charts/grafana-dashboards/
├── dashboards/<component>/  # Compiled JSON dashboards (committed)
└── rules/<component>/       # Compiled YAML rules and alerts (committed)
```

## Prerequisites

Install jsonnet tooling (required for compilation):

```bash
# Install Go if not already installed
# Then install jsonnet-bundler and mixtool
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/monitoring-mixins/mixtool/cmd/mixtool@latest

# Ensure Go bin is in PATH
export PATH=$PATH:$(go env GOPATH)/bin

# Verify installation
jb --version
mixtool --version
```

## Working with Mixins

### Initial Setup

When setting up a new mixin for the first time:

```bash
cd mixins/<component>

# Install dependencies (downloads upstream mixin from GitHub)
jb install

# Compile dashboards, alerts, and recording rules
make all
```

This downloads the upstream mixin to `vendor/` and generates compiled artifacts in `charts/grafana-dashboards/`.

### Compiling Mixins

```bash
cd mixins/<component>

# Generate everything (dashboards, alerts, recording rules)
make all

# Or generate individually
make dashboards  # Generates JSON dashboards
make alerts      # Generates alert rules YAML
make rules       # Generates recording rules YAML
```

Generated files are placed in:

- `../../charts/grafana-dashboards/dashboards/<component>/` - Dashboard JSON files
- `../../charts/grafana-dashboards/rules/<component>/` - PrometheusRule YAML files

### Updating Dependencies

```bash
cd mixins/<component>

# Update to latest upstream mixin version
make update

# Recompile with new version
make all
```

### Validating Configuration

```bash
cd mixins/<component>

# Lint the mixin for errors
make lint

# Format jsonnet files
make fmt
```

## Customizing Mixins

Each mixin has a `mixin.libsonnet` file that provides a customization layer on top of the upstream mixin. This is where you configure label selectors, alert thresholds, and other settings.

**Example Customization:**

```jsonnet
// mixins/kubernetes/mixin.libsonnet
local kubernetes = (import 'kubernetes-mixin/mixin.libsonnet');

kubernetes {
  _config+:: {
    // Override label selectors for Alloy compatibility
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',

    // Customize alert thresholds
    cpuThrottlingPercent: 30,

    // Dashboard customization
    grafanaK8s+: {
      dashboardTags: ['kubernetes', 'platform', 'mixin'],
    },
  },

  // Disable specific dashboards if not needed
  grafanaDashboards+:: {
    'unwanted-dashboard.json': null,
  },
}
```

After making changes, run `make all` to regenerate artifacts.

## Deployment

Compiled artifacts are deployed via the `grafana-dashboards` Helm chart:

```bash
# From repository root
cd charts/grafana-dashboards
helm template test . --namespace grafana
```

ArgoCD automatically syncs changes when you commit updated dashboards:

1. Modify `mixin.libsonnet` in the component directory
2. Run `make all` to recompile
3. Commit generated files to Git
4. Push to trigger ArgoCD sync

**ArgoCD Application:** `apps/grafana-dashboards.yaml` (sync wave 4)

**Deployment Workflow:**

- **Dashboards** → ConfigMaps → GrafanaDashboard CRs → Grafana Operator provisions them
- **Rules/Alerts** → PrometheusRule CRs → Prometheus Operator loads them

## Label Mapping for Grafana Alloy

Grafana Alloy uses different job labels than standard Prometheus exporters. All mixins must be customized with the following pattern:

| Standard Label        | Alloy Label Pattern                          |
| --------------------- | -------------------------------------------- |
| `job="component"`     | `job="integrations/<integration>/component"` |
| `job="node-exporter"` | `job="integrations/node_exporter"`           |

**Example Mappings:**

- kube-state-metrics: `job="integrations/kubernetes/kube-state-metrics"`
- cadvisor: `job="integrations/kubernetes/cadvisor"`
- kubelet: `job="integrations/kubernetes/kubelet"`

See individual component READMEs for specific label mappings.

## Adding a New Mixin

To add a new component mixin (e.g., argocd, cert-manager):

```bash
# 1. Create component directory
mkdir -p mixins/<component>
cd mixins/<component>

# 2. Create jsonnetfile.json
cat > jsonnetfile.json <<EOF
{
  "version": 1,
  "dependencies": [
    {
      "source": {
        "git": {
          "remote": "https://github.com/example/<component>-mixin.git",
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
cat > mixin.libsonnet <<EOF
local component = (import '<component>-mixin/mixin.libsonnet');

component {
  _config+:: {
    // Add Alloy label selectors here
  },
}
EOF

# 4. Copy Makefile from another mixin
cp ../kubernetes/Makefile .

# 5. Update Makefile paths if needed (dashboards/rules directories)
vim Makefile

# 6. Create .gitignore
cat > .gitignore <<EOF
vendor/
EOF

# 7. Install dependencies and compile
jb install
make all

# 8. Create component-specific README.md
cat > README.md <<EOF
# <Component> Mixin

See [mixins/README.md](../README.md) for general mixin documentation.

## Component-Specific Configuration

[Document any special configuration or label mappings here]
EOF

# 9. Add templates to grafana-dashboards chart
# Create templates/<component>-dashboards.yaml
# Create templates/<component>-alerts.yaml
# Create templates/<component>-rules.yaml

# 10. Update values.yaml to add component folder
# dashboards.components.<component>.folder: "<Component Name>"

# 11. Commit and push
git add .
git commit -m "Add <component>-mixin"
git push
```

## Troubleshooting

### Vendor directory missing

**Error:** `import 'kubernetes-mixin/mixin.libsonnet' not found`

**Solution:** Run `jb install` to download dependencies

### Compilation fails

**Error:** `mixtool: command not found`

**Solution:** Install mixtool: `go install github.com/monitoring-mixins/mixtool/cmd/mixtool@latest`

### Dashboards not appearing in Grafana

1. Check if GrafanaDashboard CRs are created:

   ```bash
   kubectl get grafanadashboards -n grafana
   ```

2. Check Grafana Operator logs:

   ```bash
   kubectl logs -n grafana-operator deployment/grafana-operator-controller-manager
   ```

3. Verify instance selector matches Grafana instance labels:
   ```bash
   kubectl get grafana grafana -n grafana -o yaml | grep -A 2 labels
   ```

### Rules not loading in Prometheus

1. Check if PrometheusRule CRs are created:

   ```bash
   kubectl get prometheusrules -n kube-prometheus-stack
   ```

2. Check Prometheus Operator logs:

   ```bash
   kubectl logs -n kube-prometheus-stack deployment/kube-prometheus-stack-operator
   ```

3. Verify rule selector in Prometheus matches the labels on PrometheusRule CRs

## Current Mixins

- **[kubernetes](./kubernetes/)**: Kubernetes cluster monitoring (18 dashboards)

## References

- [Monitoring Mixins Documentation](https://monitoring.mixins.dev/)
- [mixtool GitHub](https://github.com/monitoring-mixins/mixtool)
- [jsonnet-bundler GitHub](https://github.com/jsonnet-bundler/jsonnet-bundler)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Everything You Need to Know About Monitoring Mixins (Grafana Blog)](https://grafana.com/blog/2018/09/13/everything-you-need-to-know-about-monitoring-mixins/)
- [Using Kubernetes Monitoring Mixins (Container Solutions)](https://blog.container-solutions.com/using-kubernetes-monitoring-mixins)
