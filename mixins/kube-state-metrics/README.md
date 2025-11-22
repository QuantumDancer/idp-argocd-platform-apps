# kube-state-metrics Mixin

This directory contains the kube-state-metrics monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **Dashboards**: kube-state-metrics operational monitoring (if any)
- **Alerts**: List/watch operation errors, sharding configuration issues
- **Recording Rules**: Aggregated metrics for efficient querying (if any)

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component          | Standard Label                 | Alloy Label                                        |
| ------------------ | ------------------------------ | -------------------------------------------------- |
| kube-state-metrics | `job="kube-state-metrics"`     | `job="integrations/kubernetes/kube-state-metrics"` |

## Upstream Source

This mixin is based on [kubernetes/kube-state-metrics](https://github.com/kubernetes/kube-state-metrics/tree/main/jsonnet/kube-state-metrics-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [kube-state-metrics Mixin GitHub](https://github.com/kubernetes/kube-state-metrics/tree/main/jsonnet/kube-state-metrics-mixin)
- [kube-state-metrics Documentation](https://github.com/kubernetes/kube-state-metrics)
