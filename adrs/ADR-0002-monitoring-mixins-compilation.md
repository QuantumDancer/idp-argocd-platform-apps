# ADR-0002: Custom-Compiled Monitoring Mixins for Grafana Alloy Compatibility

## Context

Grafana Alloy uses a different metric labeling scheme than standard Prometheus exporters, prepending job labels with `integrations/`
(e.g., `job="integrations/kubernetes/kube-state-metrics"` instead of `job="kube-state-metrics"`).
This causes pre-built dashboard queries from third-party mixin Helm charts to return no data.

### Problem

- **Label Mismatch**: Dashboard queries use standard labels, but Alloy metrics use `integrations/` prefix
- **Cannot Modify Alloy**: The `integrations/` prefix is part of Alloy's design
- **Cannot Customize Charts**: Third-party mixin Helm charts don't expose label selector configuration
- **Need Extensibility**: Plan to add more mixins (argocd, cert-manager, cloudnative-pg) with same customization needs

## Decision

**Compile monitoring mixins from upstream jsonnet sources** with customized Alloy label selectors:

1. Store jsonnet source in `mixins/<component>/` with customization layer
2. Compile locally using `jb` and `mixtool` to generate JSON dashboards and YAML rules
3. Commit compiled artifacts to Git in `charts/grafana-dashboards/`
4. Deploy via Helm chart that creates ConfigMaps and GrafanaDashboard/PrometheusRule CRs
5. Manage via ArgoCD with automated sync

### Workflow

```bash
# Initial setup
cd mixins/kubernetes
jb install                # Download kubernetes-mixin
make all                  # Compile dashboards, alerts, rules
git commit && git push    # ArgoCD syncs automatically

# Update dashboards
vim mixin.libsonnet       # Modify configuration
make all && git commit && git push
```

### Customization

```jsonnet
// mixins/kubernetes/mixin.libsonnet
local kubernetes = (import 'kubernetes-mixin/mixin.libsonnet');

kubernetes {
  _config+:: {
    // Override selectors for Alloy compatibility
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',
    cadvisorSelector: 'job="integrations/kubernetes/cadvisor"',
    // ... etc
  },
}
```

## Alternatives Considered

**Portefaix Mixin Charts**: Continue using pre-built charts with metric relabeling or dashboard transformations. Rejected because it doesn't fix the root cause and creates fragile workarounds.

**CI/CD Compilation**: Compile in GitLab CI without committing artifacts. Rejected because it adds complexity, loses auditability (can't see compiled output with source changes), and makes rollbacks difficult.

## Implementation Notes

**Required Tools**:

```bash
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/monitoring-mixins/mixtool/cmd/mixtool@latest
export PATH=$PATH:$(go env GOPATH)/bin
```

**Adding New Mixins**:

```bash
mkdir -p mixins/<component>
cd mixins/<component>
# Create jsonnetfile.json, mixin.libsonnet, copy Makefile
jb install && make all
# Create templates/<component>-dashboards.yaml in grafana-dashboards chart
git commit && push
```

## References

- [Monitoring Mixins Documentation](https://monitoring.mixins.dev/)
- [kubernetes-mixin Repository](https://github.com/kubernetes-monitoring/kubernetes-mixin)
- [mixtool GitHub](https://github.com/monitoring-mixins/mixtool)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
