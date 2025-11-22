// Loki Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream loki-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local loki = (import 'loki-mixin/mixin.libsonnet');

loki {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    lokiSelector: 'job="integrations/loki"',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaLoki+: {
      dashboardTags: ['loki', 'observability', 'mixin'],
      dashboardNamePrefix: 'Loki / ',
      dashboardNameSuffix: '',
    },
  },
}
