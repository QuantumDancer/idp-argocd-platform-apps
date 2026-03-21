// ArgoCD Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream argocd-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.
//
// The deployed dashboard (argocd-overview.json, grafana.com/dashboards/14584)
// uses per-component job labels that the ServiceMonitor in argocd-config assigns
// via relabeling. If the mixin is ever recompiled to regenerate dashboards,
// these selectors must match those relabeling rules.

local argocd = (import 'argocd-mixin/mixin.libsonnet');

argocd {
  _config+:: {
    // Per-component job selectors to match the ServiceMonitor relabeling in
    // charts/argocd-config/templates/servicemonitor.yaml. The dashboard panels
    // for memory, goroutines, and gRPC stats are separated by component, so
    // a single shared job label would make those panels non-functional.
    applicationControllerSelector: 'job="integrations/argocd/application-controller"',
    repoServerSelector: 'job="integrations/argocd/repo-server"',
    serverSelector: 'job="integrations/argocd/argocd-server"',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaArgocd+: {
      dashboardTags: ['argocd', 'integration-and-delivery', 'mixin'],
      dashboardNamePrefix: 'ArgoCD / ',
      dashboardNameSuffix: '',
    },
  },
}
