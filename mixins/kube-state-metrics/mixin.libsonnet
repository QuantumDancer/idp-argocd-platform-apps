// kube-state-metrics Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream kube-state-metrics-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local kubeStateMetrics = (import 'kube-state-metrics-mixin/mixin.libsonnet');

kubeStateMetrics {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaKubeStateMetrics+: {
      dashboardTags: ['kube-state-metrics', 'resources-compute', 'mixin'],
      dashboardNamePrefix: 'kube-state-metrics / ',
      dashboardNameSuffix: '',
    },
  },
}
