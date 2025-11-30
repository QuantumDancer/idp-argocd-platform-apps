# PostgreSQLDatabase XRD - Testing and Validation Guide

This guide is for platform team members who need to test and validate changes to the PostgreSQLDatabase XRD and its compositions.

## Prerequisites

- `kubectl` configured to access the cluster
- `crossplane` CLI installed (`go install github.com/crossplane/crossplane@latest`)
- Access to create resources in test namespaces

## Local Validation (Before Deployment)

### 1. Validate XRD and Composition Schema

```bash
# Validate the XRD and Composition structure
crossplane beta validate \
  charts/platform-resources/templates/postgresqldatabases.idp.rottler.io/ \
  charts/platform-resources/examples/

# Expected output: All resources should validate successfully
```

### 2. Validate Example Resources

```bash
# Validate individual examples
crossplane beta validate \
  charts/platform-resources/templates/postgresqldatabases.idp.rottler.io/ \
  charts/platform-resources/examples/postgresql-small.yaml

crossplane beta validate \
  charts/platform-resources/templates/postgresqldatabases.idp.rottler.io/ \
  charts/platform-resources/examples/postgresql-medium-ha.yaml
```

### 3. Template the Helm Chart

```bash
# Render the chart to verify template syntax
helm template test charts/platform-resources/ \
  --namespace platform-resources \
  --debug

# Check for any template errors
```

### 4. Dry-Run Validation

```bash
# If you have a Kubernetes cluster available, use server-side dry-run
# (Note: This requires the XRD to already be installed in the cluster)
kubectl apply --dry-run=server \
  -f charts/platform-resources/examples/postgresql-small.yaml
```

## Deployment via ArgoCD

### 1. Commit Changes

```bash
# Stage your changes
git add charts/platform-resources/

# Commit with descriptive message
git commit -m "feat(platform-resources): Add PostgreSQLDatabase status fields"

# Push to repository
git push origin main
```

### 2. Sync ArgoCD Application

```bash
# Check ArgoCD sync status
argocd app get platform-resources

# Sync the application (if not using auto-sync)
argocd app sync platform-resources

# Monitor the sync
argocd app wait platform-resources --health
```

### 3. Verify XRD Installation

```bash
# Check that the XRD is installed
kubectl get xrd postgresqldatabases.idp.rottler.io

# Verify the XRD offers the PostgreSQLDatabase resource
kubectl api-resources | grep postgresqldatabase

# Check XRD details
kubectl get xrd postgresqldatabases.idp.rottler.io -o yaml

# Verify defaultCompositionRef is set
kubectl get xrd postgresqldatabases.idp.rottler.io \
  -o jsonpath='{.spec.defaultCompositionRef.name}'
# Expected output: postgresqldatabase-cnpg
```

### 4. Verify Composition Installation

```bash
# Check that the composition is installed
kubectl get composition postgresqldatabase-cnpg

# Verify composition labels
kubectl get composition postgresqldatabase-cnpg -o yaml | grep -A 5 labels

# Expected labels:
#   provider: cnpg
#   crossplane.io/xrd: postgresqldatabases.idp.rottler.io
```

## End-to-End Testing

### 1. Create Test Namespace

```bash
kubectl create namespace db-test
```

### 2. Deploy Small Test Database

```bash
# Apply the test database
kubectl apply -f - <<EOF
apiVersion: idp.rottler.io/v1alpha1
kind: PostgreSQLDatabase
metadata:
  name: test-small
  namespace: db-test
spec:
  compute: small
  storage: 2Gi
  version: "17"
  ha: false
EOF
```

### 3. Monitor Database Creation

```bash
# Watch the PostgreSQLDatabase resource
kubectl get postgresqldatabase -n db-test -w

# Check the status
kubectl get postgresqldatabase test-small -n db-test -o yaml

# Verify status fields are populated:
# status:
#   phase: "Cluster in healthy state" (or "Setting up primary")
#   ready: true
#   readyInstances: 1
#   connectionDetailsSecretRef: test-small-superuser
#   endpoint: test-small-rw
#   currentPrimary: test-small-1
```

### 4. Check Managed Resources

```bash
# Verify CNPG Cluster was created
kubectl get cluster -n db-test test-small

# Check cluster status
kubectl get cluster -n db-test test-small -o yaml

# Verify pods are running
kubectl get pods -n db-test -l cnpg.io/cluster=test-small

# Check services
kubectl get svc -n db-test -l cnpg.io/cluster=test-small

# Verify connection secret exists
kubectl get secret -n db-test test-small-superuser

# Check secret contents (base64 encoded)
kubectl get secret -n db-test test-small-superuser -o yaml
```

### 5. Test Database Connection

```bash
# Create a test pod to connect to the database
kubectl run -n db-test psql-test --rm -it --restart=Never \
  --image=postgres:17 \
  --env="PGHOST=test-small-rw" \
  --env="PGPORT=5432" \
  --env="PGUSER=postgres" \
  --env="PGPASSWORD=$(kubectl get secret -n db-test test-small-superuser -o jsonpath='{.data.password}' | base64 -d)" \
  -- psql -c "SELECT version();"

# Expected output: PostgreSQL version information
```

### 6. Test HA Database (3 instances)

```bash
# Apply HA test database
kubectl apply -f - <<EOF
apiVersion: idp.rottler.io/v1alpha1
kind: PostgreSQLDatabase
metadata:
  name: test-ha
  namespace: db-test
spec:
  compute: medium
  storage: 4Gi
  version: "16"
  ha: true
EOF

# Wait for all 3 instances to be ready
kubectl wait --for=condition=Ready \
  postgresqldatabase/test-ha -n db-test --timeout=300s

# Verify 3 pods are running
kubectl get pods -n db-test -l cnpg.io/cluster=test-ha
# Expected: 3 pods (test-ha-1, test-ha-2, test-ha-3)

# Check readyInstances count
kubectl get postgresqldatabase test-ha -n db-test \
  -o jsonpath='{.status.readyInstances}'
# Expected output: 3

# Verify read-only endpoint exists
kubectl get postgresqldatabase test-ha -n db-test \
  -o jsonpath='{.status.readOnlyEndpoint}'
# Expected: test-ha-ro
```

### 7. Test Status Fields

```bash
# Check all status fields are populated
kubectl get postgresqldatabase test-small -n db-test -o jsonpath='{.status}' | jq

# Verify required fields:
# - phase (string, e.g., "Cluster in healthy state")
# - ready (boolean, should be true)
# - readyInstances (integer, should be 1 for small, 3 for ha)
# - connectionDetailsSecretRef (string, e.g., "test-small-superuser")

# Verify optional fields:
# - endpoint (string, e.g., "test-small-rw")
# - readOnlyEndpoint (string, for HA only, e.g., "test-ha-ro")
# - currentPrimary (string, e.g., "test-small-1")
```

### 8. Test Failover (HA Only)

```bash
# Delete the primary pod to test failover
CURRENT_PRIMARY=$(kubectl get postgresqldatabase test-ha -n db-test -o jsonpath='{.status.currentPrimary}')
kubectl delete pod -n db-test $CURRENT_PRIMARY

# Monitor failover
kubectl get cluster -n db-test test-ha -w

# Verify new primary is elected
# After ~30 seconds, check currentPrimary has changed
kubectl get postgresqldatabase test-ha -n db-test -o jsonpath='{.status.currentPrimary}'
# Should show a different pod name
```

## Cleanup Test Resources

```bash
# Delete test databases
kubectl delete postgresqldatabase test-small -n db-test
kubectl delete postgresqldatabase test-ha -n db-test

# Wait for resources to be cleaned up
kubectl get cluster -n db-test -w

# Delete test namespace
kubectl delete namespace db-test
```

## Troubleshooting

### XRD Not Found

```bash
# Check if XRD is installed
kubectl get xrd

# If missing, check ArgoCD sync status
argocd app get platform-resources

# Check for any errors in ArgoCD
argocd app logs platform-resources
```

### Composition Not Working

```bash
# Check if composition exists
kubectl get composition postgresqldatabase-cnpg

# Check composition status
kubectl get composition postgresqldatabase-cnpg -o yaml

# Verify function-go-templating is installed
kubectl get function crossplane-contrib-function-go-templating

# Verify function-auto-ready is installed
kubectl get function crossplane-contrib-function-auto-ready
```

### Database Not Provisioning

```bash
# Check PostgreSQLDatabase status
kubectl describe postgresqldatabase <name> -n <namespace>

# Check Crossplane events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check if CNPG cluster was created
kubectl get cluster -n <namespace>

# Check CNPG operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --tail=100

# Check Crossplane logs
kubectl logs -n crossplane-system -l app=crossplane --tail=100
```

### Status Fields Not Updating

**Expected behavior during initialization**: When a database is first created, you may see warnings about optional status fields (`endpoint`, `readOnlyEndpoint`, `currentPrimary`) during the first 10-30 seconds while the CNPG cluster is initializing. These warnings are harmless and will resolve automatically once the cluster status becomes available.

```bash
# Check if function pipeline is running
kubectl describe postgresqldatabase <name> -n <namespace>

# Check function logs (if available)
kubectl get events -n <namespace> | grep function

# Verify CNPG cluster has status
kubectl get cluster <name> -n <namespace> -o jsonpath='{.status}' | jq
```

If status fields remain empty after the database is ready:
- Verify the CNPG cluster has the expected status fields
- Check Crossplane function logs for errors
- Ensure function-go-templating is running correctly

### Connection Secret Missing

```bash
# Check if secret was created by CNPG
kubectl get secrets -n <namespace> -l cnpg.io/cluster=<name>

# Verify secret name matches pattern
# Should be: <database-name>-superuser

# Check CNPG cluster events
kubectl describe cluster <name> -n <namespace>
```

## Validation Checklist

Before marking a release as ready:

- [ ] XRD validates successfully with `crossplane beta validate`
- [ ] Composition validates successfully
- [ ] All example files validate against XRD
- [ ] Helm chart templates without errors
- [ ] XRD deploys successfully via ArgoCD
- [ ] Composition deploys successfully
- [ ] Small database (non-HA) creates successfully
- [ ] HA database creates 3 instances successfully
- [ ] All required status fields are populated
- [ ] Connection secret is created with correct name
- [ ] Database is accessible from test pod
- [ ] Failover works correctly for HA databases
- [ ] Cleanup removes all managed resources
- [ ] Documentation is up to date

## Performance Benchmarks

Expected provisioning times (approximate):

- **Small database (non-HA)**: 2-3 minutes
- **Medium/Large database (HA)**: 4-6 minutes
- **Failover time (HA)**: 20-40 seconds

If provisioning takes significantly longer, check:

- Storage provisioning (PVC creation)
- Image pull times (PostgreSQL container)
- Resource constraints on nodes
- CNPG operator performance
