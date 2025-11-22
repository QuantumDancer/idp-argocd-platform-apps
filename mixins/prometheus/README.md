# Prometheus Mixin

This directory contains the Prometheus monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **2 Dashboards**: Prometheus overview, remote write monitoring
- **Alerts**: Configuration reloads, service discovery, notification queues, alertmanager connectivity, TSDB operations, remote write, rule evaluations, target/label limits
- **Recording Rules**: Aggregated metrics for efficient querying

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component  | Standard Label       | Alloy Label                      |
| ---------- | -------------------- | -------------------------------- |
| Prometheus | `job="prometheus"`   | `job="integrations/prometheus"`  |

## Upstream Source

This mixin is based on [prometheus/prometheus](https://github.com/prometheus/prometheus/tree/main/documentation/prometheus-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [Prometheus Mixin GitHub](https://github.com/prometheus/prometheus/tree/main/documentation/prometheus-mixin)
- [Prometheus Documentation](https://prometheus.io/docs/)
