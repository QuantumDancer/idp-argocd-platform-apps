// Kubernetes Mixin with custom configuration for Grafana Alloy
//
// This mixin customizes the upstream kubernetes-mixin to work with
// Grafana Alloy's metric labels, which use the "integrations/" prefix
// for job labels instead of the standard Prometheus exporter labels.

local kubernetes = (import 'kubernetes-mixin/mixin.libsonnet');
local removeAlertGroup(groups, groupName) = [
  g
  for g in groups
  if g.name != groupName
];

kubernetes {
  _config+:: {
    // Job label selectors
    // NOTE: Most metrics use Alloy's "integrations/" prefix, but API server
    // metrics come from kube-prometheus-stack ServiceMonitor with job="apiserver"
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',
    cadvisorSelector: 'job="integrations/kubernetes/cadvisor"',
    nodeExporterSelector: 'job="integrations/node_exporter"',
    kubeletSelector: 'job="integrations/kubernetes/kubelet"',
    kubeApiserverSelector: 'job="apiserver"',  // From kube-prometheus-stack ServiceMonitor

    // Cluster configuration
    showMultiCluster: false,
    clusterLabel: 'cluster',

    // Dashboard customization
    grafanaK8s+: {
      dashboardTags: ['kubernetes', 'platform', 'mixin'],
      dashboardNamePrefix: 'Kubernetes / ',
      dashboardNameSuffix: '',
    },

    // Alert configuration (scheduler and controller-manager alerts disabled below)
    kubeSchedulerSelector: 'job="integrations/kubernetes/kube-scheduler"',
    kubeControllerManagerSelector: 'job="integrations/kubernetes/kube-controller-manager"',

    // Resource thresholds (adjust as needed)
    cpuThrottlingPercent: 25,
    memoryRequestUtilizationCritical: 90,
    memoryRequestUtilizationHigh: 80,
  },

  // Disable Windows dashboards (cluster will never run Windows nodes)
  // Also disable control plane dashboards that don't have metrics available:
  // - kube-proxy: Binds to localhost only (127.0.0.1:10249) by default
  // - kube-scheduler: Not exposed in Talos, requires special config in EKS 1.28+
  // - kube-controller-manager: Not exposed in Talos, requires special config in EKS 1.28+
  // Note: API server dashboard kept as some metrics are available
  grafanaDashboards+:: {
    'k8s-resources-windows-cluster.json': null,
    'k8s-resources-windows-namespace.json': null,
    'k8s-resources-windows-pod.json': null,
    'k8s-windows-cluster-rsrc-use.json': null,
    'k8s-windows-node-rsrc-use.json': null,
    'proxy.json': null,
    'scheduler.json': null,
    'controller-manager.json': null,
  },

  // Disable control plane alerts for components that don't expose metrics
  // Remove alert groups for kube-proxy, kube-scheduler, and kube-controller-manager
  prometheusAlerts+:: {
    groups: (
      removeAlertGroup(
        removeAlertGroup(
          removeAlertGroup(super.groups, 'kubernetes-system-scheduler'),
          'kubernetes-system-controller-manager'
        ),
        'kubernetes-system-kube-proxy'
      )
    ),
  },
}
