# Kubernetes Mixin

This directory contains the Kubernetes monitoring mixin configuration, customized for use with Grafana Alloy.

**See [mixins/README.md](../README.md) for general mixin documentation, including:**

- Prerequisites and tooling installation
- Compilation workflow
- Deployment process
- Adding new mixins

## Quick Start

```bash
# First time setup
jb install

# Compile dashboards, alerts, and rules
make all

# Update upstream dependencies
make update
```

## What This Mixin Provides

- **18 Dashboards**: Kubernetes cluster monitoring, resource usage, and workload analytics
- **Alerts**: Critical conditions for Kubernetes components (API server, kubelet, nodes, pods)
- **Recording Rules**: Aggregated metrics for efficient querying

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component          | Standard Label                  | Alloy Label                                             |
| ------------------ | ------------------------------- | ------------------------------------------------------- |
| kube-state-metrics | `job="kube-state-metrics"`      | `job="integrations/kubernetes/kube-state-metrics"`      |
| cAdvisor           | `job="cadvisor"`                | `job="integrations/kubernetes/cadvisor"`                |
| Node Exporter      | `job="node-exporter"`           | `job="integrations/node_exporter"`                      |
| Kubelet            | `job="kubelet"`                 | `job="integrations/kubernetes/kubelet"`                 |
| API Server         | `job="apiserver"`               | `job="integrations/kubernetes/kube-apiserver"`          |
| Scheduler          | `job="kube-scheduler"`          | `job="integrations/kubernetes/kube-scheduler"`          |
| Controller Manager | `job="kube-controller-manager"` | `job="integrations/kubernetes/kube-controller-manager"` |

## Upstream Source

This mixin is based on [kubernetes-monitoring/kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [Kubernetes Mixin GitHub](https://github.com/kubernetes-monitoring/kubernetes-mixin)
- [Grafana k8s-monitoring Helm Chart](https://github.com/grafana/k8s-monitoring-helm)
