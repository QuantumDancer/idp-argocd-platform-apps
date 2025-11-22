// cert-manager Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream cert-manager-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local certManager = (import 'cert-manager-mixin/mixin.libsonnet');

certManager {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    certManagerJobLabel: 'cert-manager/cert-manager',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaCertManager+: {
      dashboardTags: ['cert-manager', 'resources-services', 'mixin'],
      dashboardNamePrefix: 'cert-manager / ',
      dashboardNameSuffix: '',
    },
  },
}
