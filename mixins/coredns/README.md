# CoreDNS Mixin

This directory contains the CoreDNS monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **Dashboards**: CoreDNS performance and query monitoring
- **Alerts**: DNS availability, request latency, error rates, forward performance, upstream health
- **Recording Rules**: Aggregated metrics for efficient querying (if any)

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component | Standard Label     | Alloy Label                    |
| --------- | ------------------ | ------------------------------ |
| CoreDNS   | `job="coredns"`    | `job="integrations/coredns"`   |

## Upstream Source

This mixin is based on [povilasv/coredns-mixin](https://github.com/povilasv/coredns-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [CoreDNS Mixin GitHub](https://github.com/povilasv/coredns-mixin)
- [CoreDNS Documentation](https://coredns.io/)
