# ArgoCD Mixin

This directory contains the ArgoCD monitoring mixin configuration, customized for use with Grafana Alloy.

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

- **1 Dashboard**: ArgoCD overview
- **Alerts**: Application sync status, sync failures, missing applications
- **Recording Rules**: Aggregated metrics for efficient querying (if any)

## Alloy Label Mappings

This mixin uses customized label selectors to work with Grafana Alloy:

| Component | Standard Label    | Alloy Label                  |
| --------- | ----------------- | ---------------------------- |
| ArgoCD    | `job="argocd"`    | `job="integrations/argocd"`  |

## Upstream Source

This mixin is based on [grafana/jsonnet-libs](https://github.com/grafana/jsonnet-libs/tree/master/argocd-mixin).

**Current version:** See `jsonnetfile.lock.json`

**Update to latest:**

```bash
make update
make all
```

## References

- [ArgoCD Mixin GitHub](https://github.com/grafana/jsonnet-libs/tree/master/argocd-mixin)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
