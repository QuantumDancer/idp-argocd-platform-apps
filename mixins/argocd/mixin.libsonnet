// ArgoCD Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream argocd-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local argocd = (import 'argocd-mixin/mixin.libsonnet');

argocd {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    argocdSelector: 'job="integrations/argocd"',

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
