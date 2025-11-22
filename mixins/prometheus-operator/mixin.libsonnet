// Prometheus Operator Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream prometheus-operator-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local prometheusOperator = (import 'github.com/prometheus-operator/prometheus-operator/jsonnet/mixin/mixin.libsonnet');

prometheusOperator {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    prometheusOperatorSelector: 'job="integrations/prometheus-operator"',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaPrometheusOperator+: {
      dashboardTags: ['prometheus-operator', 'observability', 'mixin'],
      dashboardNamePrefix: 'Prometheus Operator / ',
      dashboardNameSuffix: '',
    },
  },
}
