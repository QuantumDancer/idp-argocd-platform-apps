# ADR-0001: IDP Configuration Organization Using Layered Separation

## Context

As we expand our ArgoCD-based platform with IDP-specific configurations (Kyverno policies, Crossplane XRDs, platform governance rules), we need to decide how to organize these configurations in our GitOps repository.

### Current State

- 7 platform applications deployed using App-of-Apps pattern
- Minimal custom configurations (9 templates across 3 charts)
- Kyverno installed but no policies deployed yet
- Single-environment deployment (homelab)
- Application-specific configs co-located in charts (Gateway routes, Vault integrations)

### Future Requirements

- Multi-environment support (dev, prod)
- Multi-cloud deployment (homelab + AWS EKS)
- Multi-tenancy with team isolation
- Self-service capabilities via Crossplane
- Platform-wide governance and compliance policies
- Centralized observability and security

### Problem Statement

We need to determine where IDP-specific configurations should live. Key questions:

1. Should policies be co-located with applications or centralized?
2. How do we organize Crossplane XRDs and Compositions?
3. How do we support multiple environments without duplication?
4. How do we maintain clear ownership boundaries?
5. How do we ensure auditability for compliance?

## Decision

We will organize IDP configurations using a **three-layer architecture** based on scope and lifecycle:

### Layer 1: `charts/platform-policies/`

Contains cluster-wide, cross-cutting governance:

- Kyverno ClusterPolicies (security, compliance, resource management)
- Default NetworkPolicies
- Multi-tenancy RBAC policies

**Deployment**: Sync wave 0 (before applications)
**Ownership**: Platform/Security team

### Layer 2: `charts/platform-resources/`

Contains platform API definitions and abstractions:

- Crossplane XRDs (CompositeResourceDefinitions)
- Crossplane Compositions (environment-specific)
- Platform RBAC roles for teams
- Service templates

**Deployment**: Sync wave 1 (before application claims)
**Ownership**: Platform team

### Layer 3: `charts/<application>/`

Contains application-specific configurations:

- Application-specific Kyverno policies
- Gateway API routes
- Vault ClusterSecretStores
- Application RBAC
- Monitoring configurations

**Deployment**: Sync wave 2+ (per application)
**Ownership**: Application maintainers

### Guiding Principle

**"Policy Follows Scope"**:

- Cluster-scoped, cross-cutting → `platform-policies/`
- Platform API definitions → `platform-resources/`
- Application-coupled → `charts/<app>/`

## Consequences

### Positive

1. **Clear Ownership**: Platform team owns platform-policies and platform-resources; app teams own their charts
2. **Independent Versioning**: Policies can be updated without touching applications
3. **Auditability**: Security/compliance reviews have clear target directories
4. **Scalability**: Pattern supports multi-environment and multi-tenancy growth
5. **Reusability**: Platform layers are environment-agnostic
6. **Discoverability**: All policies of a type are in one place
7. **Testing Isolation**: Platform policies can be tested independently
8. **Sync Wave Clarity**: Deployment order matches dependency graph

### Negative

1. **More Directories**: Three layers instead of one flat structure
2. **Initial Overhead**: Need to create two new charts (platform-policies, platform-resources)
3. **Coordination Required**: Changes to platform APIs may affect multiple teams
4. **Learning Curve**: New contributors need to understand layer boundaries
5. **Potential Duplication**: Some policies might be debatable (platform-wide vs app-specific)

### Neutral

1. **Migration Required**: Existing environment-specific configs need refactoring
2. **Documentation Needed**: Clear guidelines for "where does X go?" decisions
3. **ArgoCD Apps**: Two additional Application manifests required

## Alternatives Considered

### Alternative 1: Co-located Configuration

**Description**: All IDP configs live in application charts (`charts/<app>/templates/`)

**Pros**:

- Simpler structure
- Tight coupling when needed
- Fewer ArgoCD applications

**Cons**:

- Cross-cutting policies scattered across charts
- Difficult to audit all policies
- Hard to reuse across environments
- Version coupling between apps and policies
- Unclear ownership for platform-wide concerns

**Rejected because**: Doesn't scale for multi-environment/multi-tenancy requirements

### Alternative 2: Single idp-config Application

**Description**: One centralized chart for all IDP configurations

**Pros**:

- Single source of truth
- Easy auditing
- Clear platform team ownership

**Cons**:

- Risk of becoming a monolith
- Loss of application-specific coupling
- Merge conflict potential
- All configurations version together
- No separation between policies and resources

**Rejected because**: Doesn't distinguish between different types of platform concerns (governance vs APIs)

### Alternative 3: Multi-Repository

**Description**: Separate Git repos for platform-policies, platform-resources, applications

**Pros**:

- Maximum isolation
- Independent access control per repo
- Different release cadences

**Cons**:

- Significant overhead for current scale
- Complex ArgoCD app-of-apps configuration
- Difficult to test cross-repo dependencies
- Overkill for single platform team

**Rejected because**: Complexity doesn't match our current scale (7 apps, single team)

## Implementation Notes

### Migration Path

1. **Phase 1**: Create `charts/platform-policies/` with initial Kyverno policies

   - Pod security standards
   - Resource requirements
   - Image scanning policies

2. **Phase 2**: Create `charts/platform-resources/` when adding Crossplane

   - Initial XRDs (Database, ManagedNamespace)
   - Dev/prod compositions

3. **Phase 3**: Refactor environment-specific configs

   - Extract hardcoded homelab values
   - Use Helm values for environment selection

4. **Preserve**: Application-specific configs remain in `charts/<app>/`

### Sync Wave Assignments

- Wave 0: Kyverno, ESO, Crossplane, `platform-policies`
- Wave 1: `platform-resources`
- Wave 2+: Applications

### Directory Structure

```
apps/
├── platform-policies.yaml
├── platform-resources.yaml
└── <existing-apps>.yaml

charts/
├── platform-policies/
├── platform-resources/
└── <existing-charts>/
```

## References

- [IDP Configuration Documentation](../docs/IDP-Configuration.md)
- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kyverno Best Practices](https://kyverno.io/policies/)
- [Using Crossplane in GitOps](https://morningspace.medium.com/using-crossplane-in-gitops-what-to-check-in-git-76c08a5ff0c4)

## Decision Makers

- Platform Team

## Date

2025-11-17
