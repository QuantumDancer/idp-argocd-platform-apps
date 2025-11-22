// Kubernetes Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream kubernetes-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local kubernetes = (import 'kubernetes-mixin/mixin.libsonnet');

kubernetes {
  _config+:: {
    // Alloy uses "integrations/" prefix for job labels
    // See: https://grafana.com/docs/alloy/latest/
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',
    cadvisorSelector: 'job="integrations/kubernetes/cadvisor"',
    nodeExporterSelector: 'job="integrations/node_exporter"',
    kubeletSelector: 'job="integrations/kubernetes/kubelet"',

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaK8s+: {
      dashboardTags: ['kubernetes', 'platform', 'mixin'],
      dashboardNamePrefix: 'Kubernetes / ',
      dashboardNameSuffix: '',
    },

    // Alert configuration
    kubeApiserverSelector: 'job="integrations/kubernetes/kube-apiserver"',
    kubeSchedulerSelector: 'job="integrations/kubernetes/kube-scheduler"',
    kubeControllerManagerSelector: 'job="integrations/kubernetes/kube-controller-manager"',

    // Resource thresholds (adjust as needed)
    cpuThrottlingPercent: 25,
    memoryRequestUtilizationCritical: 90,
    memoryRequestUtilizationHigh: 80,
  },

  // Disable Windows dashboards (cluster will never run Windows nodes)
  grafanaDashboards+:: {
    'k8s-resources-windows-cluster.json': null,
    'k8s-resources-windows-namespace.json': null,
    'k8s-resources-windows-pod.json': null,
    'k8s-windows-cluster-rsrc-use.json': null,
    'k8s-windows-node-rsrc-use.json': null,
  },
}
