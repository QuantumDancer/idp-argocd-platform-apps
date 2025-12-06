# ADR-0001: IDP Configuration Organization Using Layered Separation

## Context

The platform needs to support IDP-specific configurations (Kyverno policies, Crossplane XRDs, platform governance)
with clear organization for multi-tenancy, multi-environment deployment, and self-service capabilities.

### Requirements

- Clear separation between platform governance, platform APIs, and applications
- Support for multiple environments (dev, prod) without duplication
- Clear ownership boundaries between platform and application teams
- Auditability for compliance and governance
- Self-service capabilities via Crossplane

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

## Implementation Notes

**Sync Wave Assignments**:

- Wave 0: Kyverno, ESO, Crossplane, `platform-policies`
- Wave 1: `platform-resources`
- Wave 2+: Applications

**Directory Structure**:

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

- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kyverno Best Practices](https://kyverno.io/policies/)
- [Using Crossplane in GitOps](https://morningspace.medium.com/using-crossplane-in-gitops-what-to-check-in-git-76c08a5ff0c4)
