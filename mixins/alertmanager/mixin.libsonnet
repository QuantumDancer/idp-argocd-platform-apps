// Alertmanager Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream alertmanager-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local alertmanager = (import 'alertmanager-mixin/mixin.libsonnet');

alertmanager {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    alertmanagerSelector: 'job="integrations/alertmanager"',
    alertmanagerClusterLabels: 'cluster',
    alertmanagerCriticalIntegrationsRegEx: @'.*',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaAlertmanager+: {
      dashboardTags: ['alertmanager', 'observability', 'mixin'],
      dashboardNamePrefix: 'Alertmanager / ',
      dashboardNameSuffix: '',
    },
  },
}
