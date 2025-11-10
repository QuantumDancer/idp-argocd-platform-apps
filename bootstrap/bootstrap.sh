#!/bin/bash

echo "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd --version 9.1.0 -n argocd --create-namespace -f bootstrap/argocd-values.yaml
echo ""

echo "Applying bootstrap configuration"
kubectl apply -f bootstrap/repo.yaml
kubectl apply -f bootstrap/root-app.yaml

echo "Run this command to enable port forwarding:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
