# cert-manager Mixin

This directory contains the cert-manager monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **Dashboards**: cert-manager overview and certificate monitoring
- **Alerts**: Certificate expiry warnings, renewal failures, rate limiting, service availability
- **Recording Rules**: Aggregated metrics for efficient querying (if any)

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component    | Standard Label          | Alloy Label                        |
| ------------ | ----------------------- | ---------------------------------- |
| cert-manager | `job="cert-manager"`    | `job="integrations/cert-manager"`  |

## Upstream Source

This mixin is based on [imusmanmalik/cert-manager-mixin](https://github.com/imusmanmalik/cert-manager-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [cert-manager Mixin GitHub](https://github.com/imusmanmalik/cert-manager-mixin)
- [cert-manager Documentation](https://cert-manager.io/docs/)
