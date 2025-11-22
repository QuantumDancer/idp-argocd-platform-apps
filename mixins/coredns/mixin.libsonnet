// CoreDNS Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream coredns-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local coredns = (import 'coredns-mixin/mixin.libsonnet');

coredns {
  _config+:: {
    // This is currently being scraped by kube-prometheus-stack, so no selecter override is needed
    // // Alloy uses "integrations/" prefix for job labels
    // // See: https://grafana.com/docs/alloy/latest/
    // corednsSelector: 'job="integrations/coredns"',
    corednsSelector: 'job="coredns"',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaCoredns+: {
      dashboardTags: ['coredns', 'resources-services', 'mixin'],
      dashboardNamePrefix: 'CoreDNS / ',
      dashboardNameSuffix: '',
    },
  },
}
