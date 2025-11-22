// Grafana Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream grafana-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local grafana = (import 'grafana-mixin/mixin.libsonnet');

grafana {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    grafanaSelector: 'job="integrations/grafana"',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaGrafana+: {
      dashboardTags: ['grafana', 'observability', 'mixin'],
      dashboardNamePrefix: 'Grafana / ',
      dashboardNameSuffix: '',
    },
  },
}
