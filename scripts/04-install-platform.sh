#!/usr/bin/env bash
set -euo pipefail

: "${API_CLIENT_ID:?Set API_CLIENT_ID or export it from script 02}"

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set "podLabels.azure\.workload\.identity/use=true" \
  --set "serviceAccount.labels.azure\.workload\.identity/use=true"

kubectl get pods -n ingress-nginx
kubectl get pods -n cert-manager
