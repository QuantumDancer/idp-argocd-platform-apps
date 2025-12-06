# ADR-0004: Multi-Environment Support via Helm Templating

## Context

The platform needs to support multiple deployment environments (homelab, dev, prod) with different configurations for domains, infrastructure endpoints, and resource allocations.
Currently, environment-specific values are hardcoded in charts, making it impossible to deploy the same charts across different environments.

### Requirements

- **Multiple Environments**: Support homelab (on-premises), dev, and prod (AWS EKS)
- **Environment-Specific Configuration**: Different domains, Vault instances, resource allocations, retention periods

## Decision

We will implement **multi-environment support using Helm templating** with the following architecture:

1. **Convert `apps/` directory to Helm chart** to enable templating of Application manifests
2. **Create environment-specific values files** per chart: `charts/<chart>/environments/<env>.yaml`
3. **Template Application manifests** to reference environment-specific values using Helm
4. **Pass environment parameter** from root app (hardcoded initially, Terraform-managed future)

### Architecture

```
Root App (environment: homelab)
  → apps/ (Helm chart)
    → Application templates
      → charts/*/values.yaml (base) + charts/*/environments/<env>.yaml (overrides)
```

### Implementation

**1. Convert `apps/` to Helm Chart**

```
apps/
├── Chart.yaml              # Chart metadata
├── values.yaml             # environment: homelab
└── templates/              # Application manifests (moved from apps/*.yaml)
```

**2. Add Environment Values per Chart**

```
charts/<chart>/
├── values.yaml             # Base defaults
└── environments/
    ├── homelab.yaml        # Environment-specific overrides
    ├── dev.yaml
    └── prod.yaml
```

**3. Template Application Manifests**

Application manifests reference environment-specific values:

```yaml
# apps/templates/argocd-config.yaml
spec:
  source:
    helm:
      valueFiles:
        - values.yaml
        - environments/{{ .Values.environment }}.yaml
```

**4. Update Root App**

```yaml
# bootstrap/root-app.yaml
spec:
  source:
    path: apps
    helm:
      releaseName: platform-apps
      parameters:
        - name: environment
          value: homelab # From Terraform later
```
