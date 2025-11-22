# ADR-0002: Custom-Compiled Monitoring Mixins for Grafana Alloy Compatibility

## Context

### Current State

Our monitoring stack consists of:

- **Grafana Alloy** (via k8s-monitoring Helm chart) - Unified agent for metrics, logs, and traces
- **Prometheus** (via kube-prometheus-stack) - Metrics storage and alerting
- **Grafana** (via grafana-operator) - Visualization and dashboarding
- **Loki** - Log aggregation

We previously used pre-built mixin Helm charts from [Portefaix Hub](https://github.com/portefaix/portefaix-hub) to deploy dashboards:

- `kubernetes-mixin` v1.5.1 for Kubernetes dashboards (23 dashboards)
- `loki-mixin` v1.10.0 for Loki dashboards
- `alloy-mixin` v0.3.2 for Alloy dashboards

### Problem Statement

**Label Mismatch Between Alloy and Standard Exporters**

Grafana Alloy uses a different metric labeling scheme than standard Prometheus exporters. The k8s-monitoring chart's integrations prepend job labels with `integrations/`:

| Component          | Standard Label             | Alloy Label                                        |
| ------------------ | -------------------------- | -------------------------------------------------- |
| kube-state-metrics | `job="kube-state-metrics"` | `job="integrations/kubernetes/kube-state-metrics"` |
| cadvisor           | `job="cadvisor"`           | `job="integrations/kubernetes/cadvisor"`           |
| node-exporter      | `job="node-exporter"`      | `job="integrations/node_exporter"`                 |
| kubelet            | `job="kubelet"`            | `job="integrations/kubernetes/kubelet"`            |

**Impact**: Kubernetes dashboards from the Portefaix kubernetes-mixin chart use hardcoded label selectors that don't match Alloy's labels, causing dashboard queries to return no data.

**Example Query Failure**:

```promql
# Dashboard query (doesn't work with Alloy)
kube_node_status_allocatable{job="kube-state-metrics"}

# Required query for Alloy
kube_node_status_allocatable{job="integrations/kubernetes/kube-state-metrics"}
```

### Constraints

1. **Cannot modify Alloy labels**: The `integrations/` prefix is part of Alloy's design for namespace isolation
2. **Cannot customize Portefaix charts**: They are third-party charts with no configuration options for label selectors
3. **Need extensibility**: Plan to add more mixins (argocd, cert-manager, external-secrets) with same label customization needs
4. **GitOps workflow**: Must maintain declarative, version-controlled approach

### Future Requirements

- Support for additional monitoring mixins (argocd, cert-manager, vault, external-secrets, cloudnative-pg)
- Ability to customize alert thresholds and dashboard configurations per environment
- Keep dashboards and alerts synchronized with upstream mixin repositories
- Maintain reproducibility and auditability of monitoring configurations

## Decision

We will **compile monitoring mixins from upstream jsonnet sources** using a custom workflow that:

1. **Stores jsonnet source in `mixins/<component>/`** with customization layer for Alloy label selectors
2. **Compiles mixins locally using `jb` and `mixtool`** to generate JSON dashboards and YAML rules
3. **Commits compiled artifacts to Git** in `charts/grafana-dashboards/dashboards/` and `charts/grafana-dashboards/rules/`
4. **Deploys via Helm chart** (`charts/grafana-dashboards/`) that creates ConfigMaps and GrafanaDashboard/PrometheusRule CRs
5. **Manages via ArgoCD** with automated sync, prune, and self-heal

### Architecture

```
mixins/kubernetes/
├── jsonnetfile.json         # Dependency: kubernetes-mixin from GitHub
├── jsonnetfile.lock.json    # Pinned version (committed)
├── mixin.libsonnet          # Customization layer with Alloy selectors
├── Makefile                 # make all → compile dashboards/alerts/rules
├── vendor/                  # Downloaded dependencies (gitignored)
└── README.md

charts/grafana-dashboards/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── kubernetes-dashboards.yaml  # Creates ConfigMaps + GrafanaDashboard CRs
│   ├── kubernetes-alerts.yaml      # Creates PrometheusRule for alerts
│   └── kubernetes-rules.yaml       # Creates PrometheusRule for recording rules
├── dashboards/kubernetes/          # 23 compiled JSON files (committed)
└── rules/kubernetes/               # alerts.yaml + rules.yaml (committed)

apps/grafana-dashboards.yaml        # ArgoCD Application (sync wave 4)
```

### Workflow

**Initial Setup**:

```bash
cd mixins/kubernetes
jb install                # Download kubernetes-mixin
make all                  # Compile dashboards, alerts, rules
git add ../../charts/grafana-dashboards/
git commit && git push    # ArgoCD syncs automatically
```

**Updating Dashboards**:

```bash
cd mixins/kubernetes
vim mixin.libsonnet       # Modify configuration
make all                  # Recompile
git commit && git push
```

### Customization Example

```jsonnet
// mixins/kubernetes/mixin.libsonnet
local kubernetes = (import 'kubernetes-mixin/mixin.libsonnet');

kubernetes {
  _config+:: {
    // Override selectors for Alloy compatibility
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',
    cadvisorSelector: 'job="integrations/kubernetes/cadvisor"',
    nodeExporterSelector: 'job="integrations/node_exporter"',
    kubeletSelector: 'job="integrations/kubernetes/kubelet"',

    // Customize alert thresholds
    cpuThrottlingPercent: 25,
    memoryRequestUtilizationCritical: 90,
  },
}
```

## Consequences

### Positive

1. **Solves Label Mismatch**: Dashboards work correctly with Alloy metrics by customizing label selectors
2. **Full Control**: Can customize any aspect of mixins (selectors, thresholds, dashboard layouts)
3. **Upstream Tracking**: Direct dependency on official mixin repositories (kubernetes-monitoring/kubernetes-mixin)
4. **Extensible**: Easy to add new mixins following the same pattern
5. **GitOps Native**: Compiled artifacts committed to Git provide auditability and rollback capability
6. **No Third-Party Lag**: Not dependent on Portefaix Hub release cycles
7. **Industry Standard**: Uses standard jsonnet tooling (jb, mixtool) from monitoring-mixins community
8. **Reproducible Builds**: jsonnetfile.lock.json pins exact dependency versions
9. **Local Validation**: Can test dashboards before deployment via `helm template`
10. **ArgoCD Integration**: Seamless deployment with sync waves and health checks

### Negative

1. **Tooling Requirement**: Developers need Go, jb, and mixtool installed locally
2. **Binary Artifacts in Git**: Commits include large JSON files (~650KB total for kubernetes-mixin)
3. **Compilation Step**: Changes require explicit `make all` before committing
4. **Learning Curve**: Team needs to learn jsonnet for advanced customization
5. **Vendor Directory Management**: `vendor/` must be gitignored and regenerated via `jb install`
6. **Manual Sync**: Upstream mixin updates require manual `jb update` and recompilation
7. **Testing Complexity**: Need to validate compiled artifacts work correctly with metrics

### Neutral

1. **Additional Chart**: New `grafana-dashboards` chart alongside existing monitoring charts
2. **Dependency on jsonnet-bundler**: Adds external dependency for package management
3. **Documentation Overhead**: Need to document compilation workflow for contributors
4. **Two-Step Process**: Edit jsonnet → compile → commit (instead of edit YAML → commit)

## Alternatives Considered

### Alternative 1: Keep Using Portefaix Mixin Helm Charts

**Description**: Continue using third-party pre-built mixin charts and work around label issues

**Approach**:

- Keep `kubernetes-mixin`, `loki-mixin`, `alloy-mixin` Helm chart dependencies
- Configure Alloy to relabel metrics to match standard Prometheus labels
- Use dashboard variables or Grafana query transformations

**Pros**:

- No new tooling required
- Simple Helm-only workflow
- Pre-built charts maintained by community

**Cons**:

- **Cannot fix root cause**: Relabeling metrics wastes resources and breaks semantic meaning
- **Limited customization**: Charts don't expose selector configuration
- **Dependency lag**: Portefaix Hub may lag behind upstream mixins
- **Not extensible**: Same issue will occur for any new mixin we add
- **Workarounds are fragile**: Transformations in dashboards are harder to maintain

**Rejected because**: Doesn't solve the fundamental label mismatch and forces us into workarounds instead of proper fixes.

### Alternative 2: Runtime Jsonnet Compilation via ArgoCD

**Description**: Use ArgoCD's native jsonnet support to compile mixins at deployment time

**Approach**:

- Store jsonnet source in Git
- Configure ArgoCD Application with `source.directory.jsonnet: {}`
- ArgoCD compiles jsonnet during sync

**Pros**:

- No pre-compilation step required
- Source of truth is jsonnet (smaller Git footprint)
- ArgoCD native feature

**Cons**:

- **Runtime overhead**: Compilation happens during every sync
- **Debugging difficulty**: Errors only surface during deployment
- **Limited ArgoCD support**: Basic jsonnet support, may not handle complex dependencies
- **No local validation**: Can't test compiled output before pushing
- **Unclear build reproducibility**: ArgoCD's jsonnet environment may differ from local
- **Anti-pattern**: Configuration should be compiled, not interpreted at runtime

**Rejected because**: Violates GitOps principle of storing desired state (compiled manifests), not source code. Makes troubleshooting harder.

### Alternative 3: CI/CD Compilation Without Committing Artifacts

**Description**: Compile mixins in GitLab CI/CD pipeline, don't commit artifacts

**Approach**:

- Store only jsonnet source in Git
- GitLab CI pipeline runs `jb install && mixtool generate`
- Pipeline outputs compiled artifacts to separate branch or repo
- ArgoCD watches compiled artifact branch

**Pros**:

- Clean Git history (no binary artifacts)
- Centralized compilation environment
- Consistent tooling versions in CI

**Cons**:

- **More complex workflow**: Requires CI/CD setup and separate branch management
- **Lost auditability**: Can't see compiled output in same commit as source changes
- **Difficult rollbacks**: Rolling back source doesn't automatically rollback compiled artifacts
- **CI dependency**: Local development requires waiting for CI to compile
- **Debugging friction**: Can't inspect exact deployed manifests without CI logs
- **Separate artifact repo**: Adds complexity to GitOps structure

**Rejected because**: Complexity outweighs benefits. Committing artifacts maintains GitOps simplicity and auditability.

### Alternative 4: Grizzly for Dashboard Management

**Description**: Use [grizzly](https://github.com/grafana/grizzly) to manage dashboards as code

**Approach**:

- Store dashboards in jsonnet or YAML
- Use `grr push` to deploy directly to Grafana API
- Bypass Kubernetes resources entirely

**Pros**:

- Purpose-built tool for Grafana dashboard management
- Supports multiple formats (jsonnet, YAML, JSON)
- Drift detection between Git and Grafana

**Cons**:

- **Bypasses GitOps**: Dashboards managed outside Kubernetes/ArgoCD
- **No Kubernetes resources**: Doesn't create GrafanaDashboard CRs (needed for Grafana Operator)
- **Additional tool**: Another CLI tool to learn and maintain
- **Authentication complexity**: Needs Grafana API credentials
- **Inconsistent with platform**: Everything else deployed via ArgoCD
- **No PrometheusRule support**: Only handles dashboards, not alerts/rules

**Rejected because**: Doesn't fit ArgoCD-based GitOps platform architecture. We need Kubernetes-native resources.

### Alternative 5: Fork and Customize Portefaix Charts

**Description**: Fork Portefaix Hub repository and modify mixin charts to support label customization

**Approach**:

- Fork portefaix/portefaix-hub
- Add `values.yaml` options for label selectors
- Publish custom Helm chart repository
- Use our fork instead of upstream

**Pros**:

- Keeps Helm-only workflow
- Could contribute improvements back upstream
- Minimal workflow changes

**Cons**:

- **Maintenance burden**: Need to sync with upstream regularly
- **Custom infrastructure**: Must host our own Helm chart repository
- **Scope creep**: Would need to fork multiple charts (kubernetes-mixin, loki-mixin, etc.)
- **Upstream coordination**: Changes may not align with project goals
- **Doesn't solve core issue**: Still using pre-built charts instead of source

**Rejected because**: High maintenance overhead for something that upstream jsonnet mixins already support through customization.

## Implementation Notes

### Tooling Installation

Required tools (one-time setup):

```bash
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/monitoring-mixins/mixtool/cmd/mixtool@latest
export PATH=$PATH:$(go env GOPATH)/bin
```

### Migration from Portefaix Charts

Completed migration steps:

1. ✅ Created `mixins/kubernetes/` with customized mixin.libsonnet
2. ✅ Created `charts/grafana-dashboards/` Helm chart
3. ✅ Compiled 23 dashboards + alerts + recording rules
4. ✅ Verified Alloy label selectors work correctly
5. ✅ Removed `kubernetes-mixin` dependency from `charts/k8s-monitoring/Chart.yaml`
6. ✅ Deleted `charts/k8s-monitoring/templates/kubernetes-dashboards.yaml`
7. ✅ Created `apps/grafana-dashboards.yaml` ArgoCD Application (sync wave 4)
8. ✅ Updated `CLAUDE.md` with mixin workflow documentation

### Future Mixin Additions

Planned mixins to add following same pattern:

- **argocd-mixin**: ArgoCD monitoring dashboards and alerts
- **cert-manager-mixin**: Certificate monitoring and expiration alerts
- **external-secrets-mixin**: Secret sync monitoring
- **cloudnative-pg-mixin**: PostgreSQL cluster monitoring
- **loki-mixin**: Replace Portefaix loki-mixin with custom-compiled version

Each will follow the template:

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
- [jsonnet-bundler GitHub](https://github.com/jsonnet-bundler/jsonnet-bundler)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Everything You Need to Know About Monitoring Mixins (Grafana Blog)](https://grafana.com/blog/2018/09/13/everything-you-need-to-know-about-monitoring-mixins/)
- [Using Kubernetes Monitoring Mixins (Container Solutions)](https://blog.container-solutions.com/using-kubernetes-monitoring-mixins)
- [Grafana as Code: A Complete Guide](https://grafana.com/blog/2022/12/06/a-complete-guide-to-managing-grafana-as-code-tools-tips-and-tricks/)

## Metadata

- **Date**: 2024-11-22
- **Author**: Platform Team
- **Implemented**: Yes
- **Related ADRs**: None
- **Related Issues**: Label mismatch between Grafana Alloy and kubernetes-mixin dashboards
