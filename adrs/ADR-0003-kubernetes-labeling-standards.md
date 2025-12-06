# ADR-0003: Kubernetes Labeling Standards for IDP Platform

## Context

The platform needs standardized labeling to support multi-tenancy, multi-environment deployment, cost allocation, and RBAC.
Current labeling practices are inconsistent and lack team ownership, environment separation, and cost tracking capabilities.

### Requirements

- **Multi-tenancy**: Team ownership and isolation labels
- **Environment separation**: Distinguish dev from prod resources
- **Cost allocation**: Track resource costs by team and project
- **RBAC foundation**: Team-based access controls
- **Compliance**: Auditing and governance support
- **Preserve integrations**: Maintain existing Grafana, Prometheus, Crossplane labels

## Decision

Establish **standardized labeling convention** for all Kubernetes resources:

1. Adopt Kubernetes recommended labels as mandatory baseline
2. Extend with IDP-specific labels for multi-tenancy and cost tracking
3. Preserve existing integration labels (Grafana, Prometheus, Crossplane)
4. Enforce via Kyverno policies (audit mode initially, then enforce)

### Required Labels

**Kubernetes Standard** (all resources):

- `app.kubernetes.io/name`: Application name (e.g., `grafana`, `argocd`)
- `app.kubernetes.io/instance`: Unique identifier (e.g., `grafana-prod`)
- `app.kubernetes.io/version`: Version (e.g., `1.0.0`)
- `app.kubernetes.io/component`: Component role (e.g., `database`, `api`)
- `app.kubernetes.io/managed-by`: Managing tool (e.g., `helm`, `argocd`)

**IDP Platform** (all resources):

- `idp.rottler.io/team`: Team name (e.g., `platform`, `backend`)
- `idp.rottler.io/environment`: Environment (`dev` or `prod`)
- `idp.rottler.io/tier`: Platform layer (`platform`, `application`, `system`)

**Cost Allocation** (all resources):

- `idp.rottler.io/cost-center`: Cost center code (e.g., `platform-ops`, `eng-backend`)
- `idp.rottler.io/project`: Project identifier (e.g., `monitoring-stack`, `customer-api`)

**Integration-Specific** (preserve existing):

- `dashboards: "grafana"` - Grafana Operator discovery
- `release: "kube-prometheus-stack"` - Prometheus rule selector
- `crossplane.io/xrd` - Crossplane XRD reference
- `idp.rottler.io/dashboard-component`, `idp.rottler.io/rule-component` - Monitoring classification

### Label Value Rules

- Lowercase alphanumeric and hyphens only (`a-z`, `0-9`, `-`)
- Must start and end with alphanumeric character
- Maximum 63 characters
- Use hyphens for word separation (not underscores)

### Example

```yaml
# Platform component (Helm chart)
metadata:
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: "{{ .Chart.Name }}"
    app.kubernetes.io/instance: "{{ .Release.Name }}"
    app.kubernetes.io/version: "{{ .Chart.AppVersion }}"
    app.kubernetes.io/managed-by: "{{ .Release.Service }}"
    # IDP platform
    idp.rottler.io/tier: "platform"
    idp.rottler.io/team: "platform"
    idp.rottler.io/environment: "{{ .Values.environment }}"
    # Cost allocation
    idp.rottler.io/cost-center: "{{ .Values.costCenter }}"
    idp.rottler.io/project: "{{ .Values.project }}"
```

### Enforcement

**Kyverno ClusterPolicies** deployed in platform-policies chart:

**Audit Mode** (initial 4-6 weeks):

- Violations logged but don't block resources
- Allows gradual migration

**Enforce Mode** (after migration):

- Non-compliant resources rejected
- Existing resources grandfathered or migrated

**Key Policies**:

- Require Kubernetes standard labels (name, instance, version, managed-by)
- Require IDP labels (team, environment, tier)
- Require cost labels (cost-center, project)
- Validate environment values (must be `dev` or `prod`)
- Validate label format (lowercase alphanumeric with hyphens)

## Implementation Notes

**Migration Phases**:

1. Create Kyverno policies in audit mode
2. Update platform charts with labels
3. Monitor audit reports
4. Switch to enforce mode

**Verification**:

```bash
kubectl get policyreports -A
kubectl describe policyreport <report-name> -n <namespace>
```

## References

- [Kubernetes Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [Kubernetes Multi-Tenancy Best Practices](https://kubernetes.io/docs/concepts/security/multi-tenancy/)
- [Kyverno Policy Best Practices](https://kyverno.io/policies/)
