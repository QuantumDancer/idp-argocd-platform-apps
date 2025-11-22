# Grafana Dashboards Helm Chart

This Helm chart deploys Grafana dashboards and Prometheus rules compiled from monitoring mixins.

## Overview

This chart packages the output of monitoring mixins (dashboards, alerts, and recording rules) and deploys them to Kubernetes using:

- **ConfigMaps + GrafanaDashboard CRs**: For Grafana dashboards (via Grafana Operator)
- **PrometheusRule CRs**: For Prometheus alerts and recording rules (via Prometheus Operator)

## Directory Structure

```
charts/grafana-dashboards/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── kubernetes-dashboards.yaml      # Dashboard deployment template
│   ├── kubernetes-alerts.yaml          # Alert rules template
│   └── kubernetes-rules.yaml           # Recording rules template
├── dashboards/
│   └── kubernetes/                     # Generated from mixins/kubernetes/
│       ├── dashboard1.json
│       ├── dashboard2.json
│       └── ...
└── rules/
    └── kubernetes/                     # Generated from mixins/kubernetes/
        ├── alerts.yaml
        └── rules.yaml
```

## Prerequisites

- Grafana Operator installed and running
- Prometheus Operator installed and running
- Grafana instance with label `dashboards: "grafana"`

## Installation

This chart is deployed via ArgoCD:

```yaml
# apps/grafana-dashboards.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana-dashboards
  namespace: argocd
spec:
  source:
    repoURL: https://gitlab.home.rottlr.de/idp/platform/argocd-platform.git
    targetRevision: main
    path: charts/grafana-dashboards
  destination:
    server: https://kubernetes.default.svc
    namespace: grafana
```

## Configuration

See `values.yaml` for all configuration options.

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `grafana.instanceSelector` | Label selector for Grafana instance | `{dashboards: "grafana"}` |
| `prometheus.namespace` | Namespace for PrometheusRule CRs | `kube-prometheus-stack` |
| `dashboards.enabled` | Enable dashboard deployment | `true` |
| `rules.enabled` | Enable rules deployment | `true` |
| `rules.alerts` | Deploy alert rules | `true` |
| `rules.recordingRules` | Deploy recording rules | `true` |

## Adding New Mixins

To add dashboards and rules from a new mixin:

1. **Compile the mixin** in `mixins/<component>/`:
   ```bash
   cd mixins/<component>
   make all
   ```

2. **Create template files** in `templates/`:
   ```yaml
   # templates/<component>-dashboards.yaml
   {{- if .Values.dashboards.enabled }}
   {{- range $path, $_ := .Files.Glob "dashboards/<component>/*.json" }}
   # ... (copy pattern from kubernetes-dashboards.yaml)
   {{- end }}
   {{- end }}
   ```

3. **Deploy via ArgoCD**:
   The chart automatically includes all files in the `dashboards/` and `rules/` directories.

## How It Works

### Dashboard Deployment

1. Mixin compilation (via `make`) generates JSON dashboard files
2. Helm templates create a ConfigMap for each dashboard
3. Helm templates create a GrafanaDashboard CR referencing the ConfigMap
4. Grafana Operator watches for GrafanaDashboard CRs and provisions them

### Rules Deployment

1. Mixin compilation (via `make`) generates YAML rule files
2. Helm templates embed the YAML into PrometheusRule CRs
3. Prometheus Operator watches for PrometheusRule CRs and loads them

## Updating Dashboards

To update dashboards after modifying a mixin:

```bash
# 1. Recompile the mixin
cd mixins/kubernetes
make all

# 2. Commit the changes
git add ../../charts/grafana-dashboards/dashboards/kubernetes/
git add ../../charts/grafana-dashboards/rules/kubernetes/
git commit -m "Update kubernetes-mixin dashboards and rules"

# 3. Push to trigger ArgoCD sync
git push
```

ArgoCD will automatically detect the changes and redeploy the updated dashboards.

## Troubleshooting

### Dashboards not appearing in Grafana

1. Check if GrafanaDashboard CRs are created:
   ```bash
   kubectl get grafanadashboards -n grafana
   ```

2. Check Grafana Operator logs:
   ```bash
   kubectl logs -n grafana-operator deployment/grafana-operator-controller-manager
   ```

3. Verify instance selector matches:
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

3. Verify rule selector in Prometheus:
   ```bash
   kubectl get prometheus -n kube-prometheus-stack -o yaml | grep -A 5 ruleSelector
   ```

## References

- [Grafana Operator Documentation](https://grafana.github.io/grafana-operator/)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Monitoring Mixins](https://monitoring.mixins.dev/)
