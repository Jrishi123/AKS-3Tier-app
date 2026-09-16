#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID}"
: "${AZURE_TENANT_ID:?Set AZURE_TENANT_ID}"
: "${AZURE_RESOURCE_GROUP:?Set AZURE_RESOURCE_GROUP}"
: "${AKS_CLUSTER_NAME:?Set AKS_CLUSTER_NAME}"
: "${KEYVAULT_NAME:?Set KEYVAULT_NAME}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-myapp}"

NAMESPACE="app"
API_IDENTITY_NAME="${AKS_CLUSTER_NAME}-api-wi"
API_SA_NAME="api"

az identity create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$API_IDENTITY_NAME"

API_CLIENT_ID="$(az identity show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$API_IDENTITY_NAME" \
  --query clientId -o tsv)"

API_PRINCIPAL_ID="$(az identity show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$API_IDENTITY_NAME" \
  --query principalId -o tsv)"

KEYVAULT_ID="$(az keyvault show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$KEYVAULT_NAME" \
  --query id -o tsv)"

az role assignment create \
  --assignee-object-id "$API_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope "$KEYVAULT_ID"

OIDC_ISSUER="$(az aks show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --query oidcIssuerProfile.issuerUrl -o tsv)"

az identity federated-credential create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --identity-name "$API_IDENTITY_NAME" \
  --name api-federated-credential \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:${NAMESPACE}:${API_SA_NAME}" \
  --audiences "api://AzureADTokenExchange"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NAMESPACE" create serviceaccount "$API_SA_NAME" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NAMESPACE" annotate serviceaccount "$API_SA_NAME" \
  azure.workload.identity/client-id="$API_CLIENT_ID" \
  --overwrite

# Demo values. For the assignment, these are placed in Key Vault, not Git.
# Replace the generated password with a strong secret for a real deployment.
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)}"

az keyvault secret set --vault-name "$KEYVAULT_NAME" --name DB-HOST --value "${HELM_RELEASE_NAME}-postgres"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name DB-PORT --value "5432"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name DB-NAME --value "appdb"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name DB-USER --value "appuser"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name DB-PASSWORD --value "$DB_PASSWORD"

echo "API_CLIENT_ID=$API_CLIENT_ID"
echo "KEYVAULT_NAME=$KEYVAULT_NAME"
