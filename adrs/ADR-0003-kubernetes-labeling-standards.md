# ADR-0003: Kubernetes Labeling Standards for IDP Platform

## Context

### Current State

Our ArgoCD-based platform has grown to include multiple components across different layers:

- 7+ platform applications (ArgoCD, Grafana, Prometheus, external-secrets, Crossplane, etc.)
- Custom Crossplane XRDs for self-service resources
- Multi-component monitoring stack (Grafana, Prometheus, Loki, Alloy)
- Three-tier architecture (platform-policies, platform-resources, application charts)

**Existing Label Usage**:

Current labeling practices vary across the platform:

- **Helm standard labels**: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version` applied via helper templates (charts/grafana-dashboards/templates/\_helpers.tpl:34-41)
- **Observability labels**: Custom labels like `dashboard-component`, `rule-component` for organizing monitoring resources
- **Grafana integration**: `dashboards: "grafana"` for Grafana Operator discovery
- **Prometheus integration**: `release: "kube-prometheus-stack"` for PrometheusRule selectors
- **Crossplane labels**: `crossplane.io/xrd` for composition references
- **Security labels**: `pod-security.kubernetes.io/*` for namespace-level pod security policies
- **Ad-hoc labels**: Inconsistent application-specific labels

### Problem Statement

As we expand the IDP to support multiple application teams, we face several challenges:

1. **No multi-tenancy support**: Missing team ownership and isolation labels
2. **No environment separation**: Cannot distinguish dev from prod resources programmatically
3. **No cost allocation**: Cannot track resource costs by team or project
4. **Inconsistent labeling**: No standard for when and how to apply labels
5. **Limited RBAC support**: Cannot build team-based access controls without team labels
6. **Poor resource organization**: Difficult to query and filter resources by ownership or purpose
7. **No enforcement**: No validation to ensure labels are applied correctly

### Future Requirements

From IDP.md, the platform must support:

- **Multi-team support**: Multiple application teams with RBAC for resource access
- **Self-service**: Teams create resources from templates
- **Multi-environment**: DEV and PROD environments
- **Cost management**: Track and allocate costs to teams and projects
- **Service catalog**: Identify and classify available platform services
- **Compliance**: Support auditing and governance requirements

### Related Context

- **ADR-0001**: Established three-layer architecture (platform-policies, platform-resources, applications)
- **ADR-0002**: Defined monitoring mixin patterns with custom component labels
- **Kubernetes recommended labels**: Standard app.kubernetes.io/\* labels for interoperability

## Decision

We will establish a **comprehensive, standardized labeling convention** for all Kubernetes resources in the IDP platform that:

1. Adopts Kubernetes recommended labels as mandatory baseline
2. Extends with IDP-specific labels for multi-tenancy and cost tracking
3. Preserves existing integration labels (Grafana, Prometheus, Crossplane)
4. Enforces standards via Kyverno policies in audit mode initially
5. Provides clear migration path for existing resources

### Label Categories

#### Category 1: Kubernetes Standard Labels (Required)

All resources MUST include these labels:

| Label                          | Description                                | Example Values                             |
| ------------------------------ | ------------------------------------------ | ------------------------------------------ |
| `app.kubernetes.io/name`       | Name of the application                    | `grafana`, `argocd`, `postgresql-db`       |
| `app.kubernetes.io/instance`   | Unique instance identifier                 | `grafana-prod`, `myapp-dev`                |
| `app.kubernetes.io/version`    | Application version (semantic or git hash) | `1.0.0`, `v14.10.0`, `abc123`              |
| `app.kubernetes.io/component`  | Component role within architecture         | `database`, `api`, `controller`, `webhook` |
| `app.kubernetes.io/part-of`    | Parent application name (optional)         | `wordpress`, `api-platform`                |
| `app.kubernetes.io/managed-by` | Tool managing the resource                 | `helm`, `argocd`, `crossplane`, `kubectl`  |

**Rationale**: These labels are the Kubernetes community standard and enable interoperability with tooling ecosystem.

#### Category 2: IDP Platform Labels (Required)

All resources MUST include these IDP-specific labels:

| Label                        | Description              | Allowed Values                                     | Example                           |
| ---------------------------- | ------------------------ | -------------------------------------------------- | --------------------------------- |
| `idp.rottler.io/team`        | Team owning the resource | Short team name (lowercase, alphanumeric, hyphens) | `backend`, `platform`, `frontend` |
| `idp.rottler.io/environment` | Deployment environment   | `dev`, `prod`                                      | `prod`                            |
| `idp.rottler.io/tier`        | Platform layer           | `platform`, `application`, `system`                | `platform`                        |

**Rationale**: These labels enable multi-tenancy, environment isolation, and RBAC policies.

#### Category 3: Cost Allocation Labels (Required)

All resources MUST include these cost tracking labels:

| Label                        | Description        | Format                    | Example                                                 |
| ---------------------------- | ------------------ | ------------------------- | ------------------------------------------------------- |
| `idp.rottler.io/cost-center` | Cost center code   | Alphanumeric with hyphens | `platform-ops`, `eng-backend`, `data-team`              |
| `idp.rottler.io/project`     | Project identifier | Lowercase with hyphens    | `monitoring-stack`, `customer-api`, `database-platform` |

**Rationale**: Enables cost tracking, chargeback, and resource optimization by team and project.

#### Category 4: Observability Labels (Recommended)

Resources that expose metrics or logs SHOULD include:

| Label                       | Description       | Allowed Values        | Example   |
| --------------------------- | ----------------- | --------------------- | --------- |
| `idp.rottler.io/monitoring` | Monitoring opt-in | `enabled`, `disabled` | `enabled` |

**Rationale**: Enables selective monitoring and dashboard filtering.

#### Category 5: Integration-Specific Labels (Preserve Existing)

These labels integrate with specific platform components and MUST be preserved:

| Label                                | Purpose                              | Example                              | Used By             |
| ------------------------------------ | ------------------------------------ | ------------------------------------ | ------------------- |
| `dashboards: "grafana"`              | Grafana Operator dashboard discovery | `grafana`                            | Grafana Operator    |
| `grafana_dashboard: "1"`             | Dashboard ConfigMap marker           | `1`                                  | Grafana Operator    |
| `release: "kube-prometheus-stack"`   | Prometheus rule selector             | `kube-prometheus-stack`              | Prometheus Operator |
| `crossplane.io/xrd`                  | Crossplane XRD reference             | `postgresqldatabases.idp.rottler.io` | Crossplane          |
| `idp.rottler.io/dashboard-component` | Dashboard classification             | `kubernetes`, `argocd`               | Monitoring mixins   |
| `idp.rottler.io/rule-component`      | Alert/rule classification            | `kubernetes`, `cert-manager`         | Monitoring mixins   |

**Rationale**: These labels are required for proper integration with Grafana Operator, Prometheus Operator, and Crossplane.

### Naming Conventions

#### Label Prefix Strategy

- **Kubernetes standard**: `app.kubernetes.io/` - Reserved for Kubernetes recommended labels
- **IDP platform**: `idp.rottler.io/` - Used for all custom platform labels
- **Crossplane**: `crossplane.io/` - Provider-specific labels
- **Integration-specific**: No prefix (e.g., `dashboards`, `release`) - Required by third-party operators

#### Label Value Format Rules

All label values MUST adhere to:

1. **Character set**: Lowercase alphanumeric characters (a-z, 0-9) and hyphens (-) only
2. **Start/End**: Must begin and end with alphanumeric character
3. **Length**: Maximum 63 characters
4. **Separators**: Use hyphens for word separation (NOT underscores)

**Valid Examples**:

- `backend`
- `platform-team`
- `monitoring-stack`
- `v1-0-0`

**Invalid Examples**:

- `Backend` (uppercase)
- `platform_team` (underscore)
- `-platform` (leading hyphen)
- `team-` (trailing hyphen)

### Label Application by Resource Type

#### Platform Components (charts/\*/templates/)

All Helm charts in the platform layer:

```yaml
metadata:
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: "{{ .Chart.Name }}"
    app.kubernetes.io/instance: "{{ .Release.Name }}"
    app.kubernetes.io/version: "{{ .Chart.AppVersion | quote }}"
    app.kubernetes.io/managed-by: "{{ .Release.Service }}"

    # IDP platform
    idp.rottler.io/tier: "platform"
    idp.rottler.io/team: "platform"
    idp.rottler.io/environment: "{{ .Values.environment | default "prod" }}"

    # Cost allocation
    idp.rottler.io/cost-center: "{{ .Values.costCenter | quote }}"
    idp.rottler.io/project: "{{ .Values.project | quote }}"

    # Observability (if applicable)
    idp.rottler.io/monitoring: "enabled"
```

#### Application Deployments

Team application resources:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: prod-backend
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "2.1.0"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: customer-platform
    app.kubernetes.io/managed-by: argocd

    # IDP platform
    idp.rottler.io/tier: application
    idp.rottler.io/team: backend
    idp.rottler.io/environment: prod

    # Cost allocation
    idp.rottler.io/cost-center: eng-backend
    idp.rottler.io/project: customer-api

    # Observability
    idp.rottler.io/monitoring: enabled
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
      app.kubernetes.io/instance: myapp-prod
  template:
    metadata:
      labels:
        # Pod labels (subset of metadata labels)
        app.kubernetes.io/name: myapp
        app.kubernetes.io/instance: myapp-prod
        app.kubernetes.io/component: api
        idp.rottler.io/team: backend
        idp.rottler.io/environment: prod
```

#### Crossplane Compositions

Platform resources (XRDs and Compositions):

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgresqldatabase-cnpg
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: postgresql-composition
    app.kubernetes.io/instance: cnpg-cloudnative
    app.kubernetes.io/managed-by: crossplane

    # IDP platform
    idp.rottler.io/tier: platform
    idp.rottler.io/team: platform
    idp.rottler.io/environment: prod

    # Cost allocation
    idp.rottler.io/cost-center: platform
    idp.rottler.io/project: idp

    # Crossplane integration
    crossplane.io/xrd: postgresqldatabases.idp.rottler.io
```

#### Monitoring Resources

GrafanaDashboard and PrometheusRule resources:

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: kubernetes-apiserver
  namespace: grafana
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: kubernetes-dashboard
    app.kubernetes.io/instance: k8s-monitoring
    app.kubernetes.io/managed-by: grafana-operator

    # IDP platform
    idp.rottler.io/tier: platform
    idp.rottler.io/team: platform
    idp.rottler.io/environment: prod

    # Cost allocation
    idp.rottler.io/cost-center: platform-ops
    idp.rottler.io/project: monitoring-stack

    # Observability classification
    idp.rottler.io/dashboard-component: kubernetes

    # Grafana Operator integration (required)
    dashboards: "grafana"
```

### Enforcement Strategy

Labels will be validated and enforced using **Kyverno ClusterPolicies** deployed in the platform-policies chart.

#### Phase 1: Audit Mode (Initial Deployment)

All policies will start in **Audit** mode:

- Violations are logged but do not block resource creation
- Allows gradual migration of existing resources
- Provides visibility into compliance status

#### Phase 2: Enforce Mode (After Migration Period)

After 4-6 weeks of audit mode, policies will switch to **Enforce** mode:

- Non-compliant resources are rejected
- Ensures all new resources follow standards
- Existing resources grandfathered or migrated

#### Policy Specifications

**Policy 1: Require Kubernetes Standard Labels**

- **Scope**: Deployments, StatefulSets, DaemonSets, Jobs, CronJobs
- **Validation**: Must have `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/managed-by`
- **Initial Mode**: Audit

**Policy 2: Require IDP Platform Labels**

- **Scope**: All namespaced resources (excluding kube-system, kube-public, kube-node-lease)
- **Validation**: Must have `idp.rottler.io/team`, `idp.rottler.io/environment`, `idp.rottler.io/tier`
- **Initial Mode**: Audit

**Policy 3: Require Cost Allocation Labels**

- **Scope**: All namespaced resources (excluding system namespaces)
- **Validation**: Must have `idp.rottler.io/cost-center`, `idp.rottler.io/project`
- **Initial Mode**: Audit

**Policy 4: Validate Environment Values**

- **Scope**: Resources with `idp.rottler.io/environment` label
- **Validation**: Value must be exactly `dev` or `prod`
- **Initial Mode**: Enforce (block invalid values immediately)

**Policy 5: Validate Label Format**

- **Scope**: All resources with IDP labels
- **Validation**: Label values match regex `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`
- **Initial Mode**: Audit

**Policy 6: Team-Namespace Alignment**

- **Scope**: Resources in team namespaces (dev-_, prod-_)
- **Validation**: `idp.rottler.io/team` must match namespace prefix (e.g., namespace `prod-backend` requires `team: backend`)
- **Initial Mode**: Audit

## Consequences

### Positive

1. **Multi-Tenancy Support**: Team labels enable RBAC policies, resource quotas, and network policies per team
2. **Environment Isolation**: Environment labels allow clear separation between dev and prod resources
3. **Cost Visibility**: Cost center and project labels enable chargeback, budgeting, and optimization
4. **Resource Organization**: Standard labels improve discoverability and bulk operations
5. **Self-Service Enablement**: Templates can enforce labels automatically, ensuring compliance
6. **Compliance & Auditing**: Clear ownership and classification support governance requirements
7. **Kubernetes Alignment**: Following community standards ensures tool compatibility
8. **Automated Validation**: Kyverno policies prevent non-compliant resources
9. **Observability Integration**: Labels enable filtering and grouping in dashboards and alerts
10. **RBAC Foundation**: Team labels enable fine-grained access control policies

### Negative

1. **Migration Effort**: Existing resources need label updates across all charts and manifests
2. **Learning Curve**: Teams need to understand label requirements and conventions
3. **Metadata Overhead**: Additional labels increase manifest size slightly
4. **Policy Maintenance**: Kyverno policies require ongoing maintenance and updates
5. **Potential Label Sprawl**: Risk of teams adding excessive custom labels
6. **Documentation Burden**: Comprehensive documentation needed for adoption
7. **Initial Audit Noise**: Many violations expected during initial audit phase
8. **Cost Tracking Process**: Requires defining cost centers and project codes
9. **Helm Chart Updates**: All existing charts need values.yaml updates
10. **Testing Overhead**: Label validation adds to testing requirements

### Neutral

1. **Audit Mode Adoption**: Non-blocking validation allows gradual compliance without disruption
2. **Backward Compatibility**: Existing integration labels preserved alongside new standards
3. **Template Automation**: Helm helpers and Crossplane compositions can apply labels automatically
4. **Future Extensibility**: Label schema can be extended for additional use cases
5. **Tool Integration**: May enable future integration with cost management and governance tools

## Alternatives Considered

### Alternative 1: No Labeling Standard

**Description**: Continue with ad-hoc labeling without formal standards

**Pros**:

- No migration effort required
- No enforcement overhead
- Maximum team flexibility

**Cons**:

- Cannot support multi-tenancy
- No cost tracking capability
- Poor resource organization
- Difficult to build RBAC policies
- Incompatible with IDP goals

**Rejected because**: Incompatible with multi-team IDP requirements and platform evolution.

### Alternative 2: Minimal Labeling (Kubernetes Standard Only)

**Description**: Require only `app.kubernetes.io/*` labels without IDP extensions

**Pros**:

- Simpler standard
- Kubernetes community alignment
- Lower learning curve

**Cons**:

- No team ownership tracking
- No environment separation
- No cost allocation
- Cannot build multi-tenancy
- Limited IDP features

**Rejected because**: Insufficient for IDP-specific requirements like multi-tenancy and cost tracking.

### Alternative 3: Third-Party Labeling Tools

**Description**: Use external tools like Kubecost or Fairwinds Goldilocks for labeling

**Pros**:

- Pre-built label schemas
- Integrated cost management
- Vendor support

**Cons**:

- Vendor lock-in
- Additional tool complexity
- May not match IDP requirements
- External dependencies
- Licensing costs

**Rejected because**: Unnecessary complexity; GitOps approach with Kyverno is sufficient.

### Alternative 4: Immediate Full Enforcement

**Description**: Deploy policies in enforce mode immediately without audit phase

**Pros**:

- Immediate compliance
- Clear expectations
- No technical debt

**Cons**:

- Breaks existing deployments
- No migration path
- Disruptive to teams
- High initial friction
- Blocks platform evolution

**Rejected because**: Too disruptive; audit mode provides safer migration path.

## Implementation Notes

### Migration Strategy

#### Phase 1: Documentation & Policy Creation (Week 1)

1. Merge ADR-0003 to main branch
2. Create Kyverno policies in `charts/platform-policies/templates/label-validation.yaml`
3. Set all policies to `validationFailureAction: Audit`
4. Deploy policies via ArgoCD (sync wave 0)
5. Monitor audit logs for violations

#### Phase 2: Platform Layer Migration (Weeks 2-3)

1. Update all charts in `charts/` directory:
   - Add IDP labels to Chart.yaml and values.yaml
   - Update \_helpers.tpl templates with new labels
   - Add cost-center and project values
2. Update ArgoCD Applications in `apps/` directory
3. Update bootstrap layer resources
4. Document label values for each component

#### Phase 3: Platform Resources (Week 3)

1. Update Crossplane XRDs and Compositions
2. Add labels to platform-policies resources
3. Add labels to platform-resources
4. Verify monitoring resources maintain integration labels

#### Phase 4: Monitoring & Refinement (Weeks 4-6)

1. Monitor Kyverno audit reports via Prometheus/Grafana
2. Identify common violations and edge cases
3. Refine label values and conventions
4. Update documentation with lessons learned
5. Create team onboarding guide

#### Phase 5: Enforcement (Week 7+)

1. Switch policies to `validationFailureAction: Enforce`
2. Monitor for blocked resources
3. Provide team support for compliance
4. Document exception process

### Label Reference Table

| Label                                | Category        | Required    | Format                              | Example                              | Applicable Resources   |
| ------------------------------------ | --------------- | ----------- | ----------------------------------- | ------------------------------------ | ---------------------- |
| `app.kubernetes.io/name`             | K8s Standard    | Yes         | lowercase-hyphen                    | `grafana`                            | All                    |
| `app.kubernetes.io/instance`         | K8s Standard    | Yes         | lowercase-hyphen                    | `grafana-prod`                       | All                    |
| `app.kubernetes.io/version`          | K8s Standard    | Yes         | semver or hash                      | `1.0.0`                              | All                    |
| `app.kubernetes.io/component`        | K8s Standard    | Yes         | lowercase-hyphen                    | `database`                           | All                    |
| `app.kubernetes.io/part-of`          | K8s Standard    | Recommended | lowercase-hyphen                    | `wordpress`                          | Multi-component apps   |
| `app.kubernetes.io/managed-by`       | K8s Standard    | Yes         | tool name                           | `helm`                               | All                    |
| `idp.rottler.io/team`                | IDP Platform    | Yes         | lowercase-hyphen                    | `backend`                            | All                    |
| `idp.rottler.io/environment`         | IDP Platform    | Yes         | enum: dev, prod                     | `prod`                               | All                    |
| `idp.rottler.io/tier`                | IDP Platform    | Yes         | enum: platform, application, system | `platform`                           | All                    |
| `idp.rottler.io/cost-center`         | Cost Allocation | Yes         | lowercase-hyphen                    | `platform-ops`                       | All                    |
| `idp.rottler.io/project`             | Cost Allocation | Yes         | lowercase-hyphen                    | `monitoring-stack`                   | All                    |
| `idp.rottler.io/monitoring`          | Observability   | Recommended | enum: enabled, disabled             | `enabled`                            | Monitored resources    |
| `idp.rottler.io/dashboard-component` | Observability   | Conditional | lowercase-hyphen                    | `kubernetes`                         | GrafanaDashboard       |
| `idp.rottler.io/rule-component`      | Observability   | Conditional | lowercase-hyphen                    | `argocd`                             | PrometheusRule         |
| `dashboards`                         | Integration     | Conditional | literal                             | `grafana`                            | GrafanaDashboard       |
| `grafana_dashboard`                  | Integration     | Conditional | literal                             | `1`                                  | Dashboard ConfigMap    |
| `release`                            | Integration     | Conditional | literal                             | `kube-prometheus-stack`              | PrometheusRule         |
| `crossplane.io/xrd`                  | Integration     | Conditional | FQDN                                | `postgresqldatabases.idp.rottler.io` | Crossplane Composition |

### Concrete Examples

#### Example 1: Platform Component (Grafana)

File: `charts/grafana/templates/grafana.yaml`

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
  namespace: grafana
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: grafana
    app.kubernetes.io/instance: grafana
    app.kubernetes.io/version: "12.3.0"
    app.kubernetes.io/component: observability
    app.kubernetes.io/managed-by: helm

    # IDP platform
    idp.rottler.io/tier: platform
    idp.rottler.io/team: platform
    idp.rottler.io/environment: prod

    # Cost allocation
    idp.rottler.io/cost-center: platform-ops
    idp.rottler.io/project: monitoring-stack

    # Observability
    idp.rottler.io/monitoring: enabled

    # Grafana Operator integration
    dashboards: grafana
```

#### Example 2: Team Application Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customer-api
  namespace: prod-backend
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: customer-api
    app.kubernetes.io/instance: customer-api-prod
    app.kubernetes.io/version: "2.1.0"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: customer-platform
    app.kubernetes.io/managed-by: argocd

    # IDP platform
    idp.rottler.io/tier: application
    idp.rottler.io/team: backend
    idp.rottler.io/environment: prod

    # Cost allocation
    idp.rottler.io/cost-center: eng-backend
    idp.rottler.io/project: customer-services

    # Observability
    idp.rottler.io/monitoring: enabled
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: customer-api
      app.kubernetes.io/instance: customer-api-prod
  template:
    metadata:
      labels:
        app.kubernetes.io/name: customer-api
        app.kubernetes.io/instance: customer-api-prod
        app.kubernetes.io/component: api
        idp.rottler.io/team: backend
        idp.rottler.io/environment: prod
        idp.rottler.io/monitoring: enabled
    spec:
      containers:
        - name: api
          image: registry.example.com/customer-api:2.1.0
          ports:
            - containerPort: 8080
```

#### Example 3: Crossplane Composition (PostgreSQL)

File: `charts/platform-resources/templates/postgresqldatabases.idp.rottler.io/composition-cnpg.yaml`

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgresqldatabase-cnpg
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: postgresql-composition
    app.kubernetes.io/instance: cnpg-cloudnative
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: database-composition
    app.kubernetes.io/managed-by: crossplane

    # IDP platform
    idp.rottler.io/tier: platform
    idp.rottler.io/team: platform
    idp.rottler.io/environment: prod

    # Cost allocation
    idp.rottler.io/cost-center: platform-data
    idp.rottler.io/project: database-platform

    # Crossplane integration
    crossplane.io/xrd: postgresqldatabases.idp.rottler.io
spec:
  compositeTypeRef:
    apiVersion: idp.rottler.io/v1alpha1
    kind: PostgreSQLDatabase
  resources:
    - name: cluster
      base:
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        metadata:
          labels:
            # Propagate labels to managed resources
            app.kubernetes.io/managed-by: crossplane
            idp.rottler.io/tier: platform
            idp.rottler.io/team: platform
        spec:
          instances: 3
          storage:
            size: 10Gi
```

#### Example 4: GrafanaDashboard (Monitoring)

File: `charts/grafana-dashboards/templates/kubernetes-dashboards.yaml`

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: kubernetes-apiserver
  namespace: grafana
  labels:
    # Kubernetes standard
    app.kubernetes.io/name: kubernetes-dashboard
    app.kubernetes.io/instance: k8s-monitoring
    app.kubernetes.io/version: "1.5.1"
    app.kubernetes.io/component: dashboard
    app.kubernetes.io/managed-by: grafana-operator

    # IDP platform
    idp.rottler.io/tier: platform
    idp.rottler.io/team: platform
    idp.rottler.io/environment: prod

    # Cost allocation
    idp.rottler.io/cost-center: platform-ops
    idp.rottler.io/project: monitoring-stack

    # Observability classification
    idp.rottler.io/dashboard-component: kubernetes
    idp.rottler.io/monitoring: enabled

    # Grafana Operator integration (required)
    dashboards: grafana
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  configMapRef:
    name: kubernetes-apiserver-dashboard
    key: apiserver.json
```

### Team Onboarding Guide

When creating resources, teams should:

1. **Choose Team Identifier**: Use short, descriptive name (e.g., `backend`, `frontend`, `data`)

   - Coordinate with platform team to register team name
   - Use consistently across all resources

2. **Define Cost Center**: Obtain cost center code from finance team

   - Format: `{department}-{identifier}` (e.g., `eng-backend`, `product-mobile`)

3. **Define Project**: Use descriptive project identifier

   - Format: `{service}-{component}` (e.g., `customer-api`, `payment-gateway`)
   - Projects can span multiple resources

4. **Apply Labels via Helm**: Use Helm values for consistency

   ```yaml
   # values.yaml
   labels:
     team: backend
     environment: prod
     costCenter: eng-backend
     project: customer-services
   ```

5. **Verify Compliance**: Check Kyverno audit reports

   ```bash
   kubectl get policyreports -A
   kubectl describe policyreport <report-name> -n <namespace>
   ```

6. **Use Label Helpers**: Reference existing charts for Helm helper patterns
   - See `charts/grafana-dashboards/templates/_helpers.tpl` for example

### Cost Center Codes

Platform team maintains registry of cost centers:

| Team     | Cost Center Code | Description                            |
| -------- | ---------------- | -------------------------------------- |
| platform | platform-ops     | Platform operations and infrastructure |
| platform | platform-data    | Database and data platform services    |
| backend  | eng-backend      | Backend engineering team               |
| frontend | eng-frontend     | Frontend engineering team              |
| data     | data-analytics   | Data analytics and ML team             |

Projects are defined by teams and tracked in team documentation.

## References

- [Kubernetes Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [Kubernetes Multi-Tenancy Best Practices](https://kubernetes.io/docs/concepts/security/multi-tenancy/)
- [Kubernetes Labels Guide (Cast.ai)](https://cast.ai/blog/kubernetes-labels-expert-guide-with-10-best-practices/)
- [Best Practices for Kubernetes Labels (Komodor)](https://komodor.com/blog/best-practices-guide-for-kubernetes-labels-and-annotations/)
- [Kubernetes Labels Best Practices (CloudZero)](https://www.cloudzero.com/blog/kubernetes-labels-best-practices)
- [GKE Cluster Multi-Tenancy](https://cloud.google.com/kubernetes-engine/docs/concepts/multitenancy-overview)
- [Kyverno Policy Best Practices](https://kyverno.io/policies/)
- ADR-0001: IDP Configuration Organization
- ADR-0002: Monitoring Mixins Compilation
- IDP.md: Platform Goals and Requirements

## Metadata

- **Date**: 2025-11-30
- **Decision Makers**: Platform Team
- **Status**: Approved
- **Related ADRs**: ADR-0001 (Platform Organization), ADR-0002 (Monitoring Mixins)
- **Implementation Status**: Planned (Policy creation and migration pending)
