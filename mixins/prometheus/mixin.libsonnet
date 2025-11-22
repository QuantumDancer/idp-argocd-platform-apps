// Prometheus Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream prometheus-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local prometheus = (import 'prometheus-mixin/mixin.libsonnet');

prometheus {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    prometheusSelector: 'job="integrations/prometheus"',
    prometheusName: '{{ $labels.job }}',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaPrometheus+: {
      dashboardTags: ['prometheus', 'observability', 'mixin'],
      dashboardNamePrefix: 'Prometheus / ',
      dashboardNameSuffix: '',
    },
  },
}
