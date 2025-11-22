# Grafana Mixin

This directory contains the Grafana monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **1 Dashboard**: Grafana overview
- **Alerts**: HTTP request failures and error rates
- **Recording Rules**: Aggregated metrics for efficient querying (if any)

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component | Standard Label    | Alloy Label                  |
| --------- | ----------------- | ---------------------------- |
| Grafana   | `job="grafana"`   | `job="integrations/grafana"` |

## Upstream Source

This mixin is based on [grafana/grafana](https://github.com/grafana/grafana/tree/main/grafana-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [Grafana Mixin GitHub](https://github.com/grafana/grafana/tree/main/grafana-mixin)
- [Grafana Documentation](https://grafana.com/docs/)
