# Vendored Manifests

This directory contains upstream Kubernetes manifests that are vendored directly into this repository rather than referenced from an external source. This is used for operators and components that do not publish an official Helm chart.

Each subdirectory is an ArgoCD Application source — ArgoCD applies the manifests as plain YAML using server-side apply.

## Manifests

| Directory            | Component                 | Version | Upstream release                                      |
| -------------------- | ------------------------- | ------- | ----------------------------------------------------- |
| `rabbitmq-operator/`           | RabbitMQ Cluster Operator            | v2.21.0 | https://github.com/rabbitmq/cluster-operator/releases            |
| `rabbitmq-topology-operator/` | RabbitMQ Messaging Topology Operator | v1.19.2 | https://github.com/rabbitmq/messaging-topology-operator/releases |

## Updating a manifest

Download the new release artifact and overwrite the existing file, then commit:

```bash
# Example: upgrading the RabbitMQ Cluster Operator
curl -L https://github.com/rabbitmq/cluster-operator/releases/download/vX.Y.Z/cluster-operator.yml \
  -o manifests/rabbitmq-operator/cluster-operator.yml
git add manifests/rabbitmq-operator/cluster-operator.yml
git commit -m "Upgrade RabbitMQ cluster-operator to vX.Y.Z"
```

ArgoCD will detect the change and apply the updated manifests automatically after the commit is pushed.
