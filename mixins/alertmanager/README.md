# Alertmanager Mixin

This directory contains the Alertmanager monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **1 Dashboard**: Alertmanager overview
- **Alerts**: Alertmanager configuration reloads, cluster health, notification failures, crashlooping instances
- **Recording Rules**: Aggregated metrics for efficient querying (if any)

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component    | Standard Label         | Alloy Label                       |
| ------------ | ---------------------- | --------------------------------- |
| Alertmanager | `job="alertmanager"`   | `job="integrations/alertmanager"` |

## Upstream Source

This mixin is based on [prometheus/alertmanager](https://github.com/prometheus/alertmanager/tree/main/doc/alertmanager-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [Alertmanager Mixin GitHub](https://github.com/prometheus/alertmanager/tree/main/doc/alertmanager-mixin)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
