# Loki Mixin

This directory contains the Loki monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **14 Dashboards**: Bloom builds, chunk management, reads/writes, retention, operational monitoring
- **Alerts**: Request errors, latency, panics, compactor failures
- **Recording Rules**: Performance metrics aggregation

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component | Standard Label | Alloy Label               |
| --------- | -------------- | ------------------------- |
| Loki      | `job="loki"`   | `job="integrations/loki"` |

## Upstream Source

This mixin is based on [grafana/loki](https://github.com/grafana/loki/tree/main/production/loki-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [Loki Mixin GitHub](https://github.com/grafana/loki/tree/main/production/loki-mixin)
- [Loki Documentation](https://grafana.com/docs/loki/)
