# Prometheus Operator Mixin

This directory contains the Prometheus Operator monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **Dashboards**: Prometheus Operator operational monitoring (if any)
- **Alerts**: Controller operation errors (list, watch, sync, reconcile), status updates, node lookups, resource rejections, config-reloader failures
- **Recording Rules**: Aggregated metrics for efficient querying (if any)

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component           | Standard Label                | Alloy Label                                  |
| ------------------- | ----------------------------- | -------------------------------------------- |
| Prometheus Operator | `job="prometheus-operator"`   | `job="integrations/prometheus-operator"`     |

## Upstream Source

This mixin is based on [prometheus-operator/prometheus-operator](https://github.com/prometheus-operator/prometheus-operator/tree/main/jsonnet/mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [Prometheus Operator Mixin GitHub](https://github.com/prometheus-operator/prometheus-operator/tree/main/jsonnet/mixin)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
