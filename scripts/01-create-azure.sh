#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID}"
: "${AZURE_LOCATION:?Set AZURE_LOCATION}"
: "${AZURE_RESOURCE_GROUP:?Set AZURE_RESOURCE_GROUP}"
: "${AKS_CLUSTER_NAME:?Set AKS_CLUSTER_NAME}"
: "${ACR_NAME:?Set ACR_NAME}"
: "${KEYVAULT_NAME:?Set KEYVAULT_NAME}"
: "${DNS_ZONE:?Set DNS_ZONE}"

az account set --subscription "$AZURE_SUBSCRIPTION_ID"

az group create \
  --name "$AZURE_RESOURCE_GROUP" \
  --location "$AZURE_LOCATION"

az acr create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic

az keyvault create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$KEYVAULT_NAME" \
  --location "$AZURE_LOCATION" \
  --enable-rbac-authorization true

az network dns zone create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$DNS_ZONE"

az aks create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --location "$AZURE_LOCATION" \
  --node-count 2 \
  --node-vm-size Standard_D2s_v5 \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-addons azure-keyvault-secrets-provider \
  --attach-acr "$ACR_NAME" \
  --generate-ssh-keys

az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --overwrite-existing

kubectl get nodes
