#!/bin/sh

echo "Setting up Helm repositories..."

# Add all repositories used in this project
helm repo add jetstack https://charts.jetstack.io
helm repo add external-secrets https://charts.external-secrets.io
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo add longhorn https://charts.longhorn.io
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add cloudnative-pg https://cloudnative-pg.github.io/charts
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add portefaix https://charts.portefaix.xyz

# Update repository indices
helm repo update

echo "✓ Helm repositories configured"
