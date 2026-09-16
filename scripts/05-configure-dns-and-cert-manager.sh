#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID}"
: "${AZURE_TENANT_ID:?Set AZURE_TENANT_ID}"
: "${AZURE_RESOURCE_GROUP:?Set AZURE_RESOURCE_GROUP}"
: "${AKS_CLUSTER_NAME:?Set AKS_CLUSTER_NAME}"
: "${DNS_ZONE:?Set DNS_ZONE}"
: "${APP_HOST:?Set APP_HOST}"

INGRESS_NAMESPACE="ingress-nginx"
CERT_NAMESPACE="cert-manager"
CERT_IDENTITY_NAME="${AKS_CLUSTER_NAME}-cert-manager"

PUBLIC_IP=""

for i in $(seq 1 60); do
  PUBLIC_IP="$(kubectl get svc ingress-nginx-controller -n "$INGRESS_NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  if [[ -n "$PUBLIC_IP" ]]; then
    break
  fi
  echo "Waiting for ingress public IP..."
  sleep 10
done

if [[ -z "$PUBLIC_IP" ]]; then
  echo "Ingress public IP was not assigned."
  exit 1
fi

az network dns record-set a create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "$DNS_ZONE" \
  --name "${APP_HOST%%.$DNS_ZONE}" \
  --ttl 300

az network dns record-set a add-record \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "$DNS_ZONE" \
  --record-set-name "${APP_HOST%%.$DNS_ZONE}" \
  --ipv4-address "$PUBLIC_IP"

az identity create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$CERT_IDENTITY_NAME" \
  >/dev/null

CERT_CLIENT_ID="$(az identity show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$CERT_IDENTITY_NAME" \
  --query clientId -o tsv)"

CERT_PRINCIPAL_ID="$(az identity show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$CERT_IDENTITY_NAME" \
  --query principalId -o tsv)"

DNS_ZONE_ID="$(az network dns zone show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$DNS_ZONE" \
  --query id -o tsv)"

az role assignment create \
  --assignee-object-id "$CERT_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "DNS Zone Contributor" \
  --scope "$DNS_ZONE_ID" >/dev/null

OIDC_ISSUER="$(az aks show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --query oidcIssuerProfile.issuerUrl -o tsv)"

az identity federated-credential create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --identity-name "$CERT_IDENTITY_NAME" \
  --name cert-manager-federated-credential \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:${CERT_NAMESPACE}:cert-manager" \
  --audiences "api://AzureADTokenExchange" \
  >/dev/null

kubectl annotate serviceaccount cert-manager \
  -n "$CERT_NAMESPACE" \
  azure.workload.identity/client-id="$CERT_CLIENT_ID" \
  --overwrite

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: admin@${DNS_ZONE}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - dns01:
          azureDNS:
            hostedZoneName: ${DNS_ZONE}
            resourceGroupName: ${AZURE_RESOURCE_GROUP}
            subscriptionID: ${AZURE_SUBSCRIPTION_ID}
            tenantID: ${AZURE_TENANT_ID}
            environment: AzurePublicCloud
            managedIdentity:
              clientID: ${CERT_CLIENT_ID}
EOF

echo "APP_HOST=$APP_HOST"
echo "PUBLIC_IP=$PUBLIC_IP"
echo "CERT_CLIENT_ID=$CERT_CLIENT_ID"
