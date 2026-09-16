# AKS 3-Tier Secure Helm POC

Azure-only 3-tier application POC for a panel walkthrough:

- React frontend served by NGINX
- Node.js API
- PostgreSQL with PVC
- Parent Helm chart with linked frontend/api/postgres subcharts
- `values.schema.json` validation
- Helm pre-install/pre-upgrade migration Job
- Azure Key Vault + Secrets Store CSI Driver + Microsoft Entra Workload Identity
- PostgreSQL NetworkPolicy: API pods only
- NGINX Ingress: `/` -> frontend, `/api` -> API
- cert-manager + Let's Encrypt DNS-01 using Azure DNS
- HTTP -> HTTPS redirect
- Azure DNS A record to the NGINX public IP

## Repository layout

```text
aks-3tier-poc/
├── app/
│   ├── frontend/
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── package.json
│   │   ├── index.html
│   │   └── src/
│   │       ├── App.jsx
│   │       └── main.jsx
│   └── api/
│       ├── Dockerfile
│       ├── package.json
│       └── server.js
├── charts/
│   ├── frontend/
│   ├── api/
│   └── postgres/
├── templates/
├── scripts/
├── values.yaml
├── values.schema.json
├── Chart.yaml
└── README.md
```

## Prerequisites

Install:

- Azure CLI
- kubectl
- Helm 3
- Docker
- An Azure subscription
- A registered domain whose DNS zone is hosted in Azure DNS

Verify:

```bash
az version
kubectl version --client
helm version
docker version
```

## 1. Azure variables

Copy and edit:

```bash
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export AZURE_TENANT_ID="<tenant-id>"
export AZURE_LOCATION="centralindia"
export AZURE_RESOURCE_GROUP="rg-aks-3tier-poc"
export AKS_CLUSTER_NAME="aks-3tier-poc"
export ACR_NAME="<globally-unique-acr-name>"
export KEYVAULT_NAME="<globally-unique-keyvault-name>"
export DNS_ZONE="example.com"
export APP_HOST="app.example.com"
```

Login:

```bash
az login
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
```

## 2. Create Azure infrastructure

Run:

```bash
./scripts/01-create-azure.sh
```

This creates:

- Resource group
- Azure Container Registry
- Azure Key Vault with RBAC authorization
- Azure DNS zone
- AKS with OIDC issuer, Workload Identity and Azure Key Vault CSI provider

The AKS configuration follows Microsoft's current Workload Identity and Key Vault CSI patterns.

## 3. Get cluster credentials

```bash
az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --overwrite-existing

kubectl get nodes
```

## 4. Create Key Vault secrets and application identity

Run:

```bash
./scripts/02-configure-identities-and-secrets.sh
```

This creates:

- API user-assigned managed identity
- Kubernetes API ServiceAccount
- Federated identity credential
- Key Vault RBAC assignment
- Database secrets in Key Vault

No application secret is stored in Git.

## 5. Build and push application images

```bash
./scripts/03-build-push-images.sh
```

The script builds:

- React/NGINX frontend
- Node.js API

and pushes them to ACR.

## 6. Install NGINX Ingress

```bash
./scripts/04-install-platform.sh
```

This installs:

- ingress-nginx
- cert-manager

The cert-manager installation is configured for Azure Workload Identity.

## 7. Configure Azure DNS and cert-manager

Run:

```bash
./scripts/05-configure-dns-and-cert-manager.sh
```

This:

1. Gets the NGINX LoadBalancer public IP.
2. Creates/updates the Azure DNS A record.
3. Creates the cert-manager Azure DNS managed identity.
4. Creates the federated identity credential for cert-manager.
5. Grants DNS Zone Contributor to that identity.
6. Applies the Let's Encrypt ClusterIssuer.

The repository uses DNS-01 validation, so the certificate can be issued through Azure DNS without exposing a temporary HTTP challenge endpoint.

## 8. Update Helm values

Edit `values.yaml`:

```yaml
global:
  domain: app.example.com
  keyVault:
    name: "<your-key-vault>"
    tenantId: "<your-tenant-id>"
    clientId: "<api-managed-identity-client-id>"
```

The image repositories should also match your ACR.

## 9. Validate the chart

From the repository root:

```bash
helm dependency build
helm lint .
helm template myapp . --namespace app
```

Test schema rejection:

```bash
helm template myapp . \
  --set api.enabled=yes
```

This should fail because `api.enabled` must be boolean.

Test missing limits by temporarily removing `api.resources.limits`:

```bash
helm lint .
```

This should fail schema validation.

## 10. Deploy

```bash
helm upgrade --install myapp . \
  --namespace app \
  --create-namespace \
  --wait \
  --timeout 10m
```

Check:

```bash
kubectl get pods -n app
kubectl get svc -n app
kubectl get pvc -n app
kubectl get jobs -n app
kubectl get ingress -n app
kubectl get certificate -n app
```

## 11. Verify migration hook

```bash
kubectl get jobs -n app
kubectl logs -n app job/<migration-job-name>
```

The migration is intentionally simulated for this POC. It runs as a Helm `pre-install,pre-upgrade` hook before the API resources are rolled out.

## 12. Verify Key Vault injection

```bash
kubectl get secret -n app
kubectl describe secret -n app api-db-secrets
```

Do not print the secret value during the panel demo.

The API receives:

- DB_HOST
- DB_PORT
- DB_NAME
- DB_USER
- DB_PASSWORD

from the Kubernetes Secret synchronized by the Secrets Store CSI Driver.

## 13. Verify NetworkPolicy

```bash
kubectl get networkpolicy -n app
kubectl describe networkpolicy -n app postgres-ingress
```

PostgreSQL is intended to accept traffic only from API pods.

## 14. Verify TLS

```bash
kubectl get clusterissuer
kubectl get certificate -n app
kubectl describe certificate -n app app-tls
kubectl get secret -n app app-tls
```

Then:

```bash
curl -I "http://${APP_HOST}"
curl -I "https://${APP_HOST}"
```

HTTP should redirect to HTTPS.

## 15. Useful panel demo changes

### Disable frontend

```yaml
frontend:
  enabled: false
```

Then:

```bash
helm upgrade myapp . -n app
kubectl get deployment -n app
```

### Disable PostgreSQL

```yaml
postgres:
  enabled: false
```

The PostgreSQL subchart is controlled by the parent dependency condition.

### Break schema

```yaml
api:
  enabled: "yes"
```

Then:

```bash
helm lint .
```

Expected: validation failure.

## Important production discussion

This is a POC that intentionally runs PostgreSQL inside AKS because the assignment requires a containerized PostgreSQL database with a PVC.

For a production Azure design, discuss Azure Database for PostgreSQL as a managed database alternative for HA, backups, patching and operational simplicity.

Likewise, the migration Job is deliberately simple for demonstration. A production migration workflow should be designed around the organization's release and rollback strategy.

## Panel explanation

The shortest architecture explanation:

> "The parent Helm chart deploys three linked subcharts: frontend, API and PostgreSQL. NGINX Ingress is the single external entry point and routes `/` to the frontend and `/api` to the API. PostgreSQL remains internal and has a NetworkPolicy allowing ingress only from API pods. PostgreSQL uses a PVC for persistence. Secrets are stored in Azure Key Vault and accessed through Microsoft Entra Workload Identity and the Secrets Store CSI Driver. cert-manager obtains and renews a Let's Encrypt certificate using Azure DNS DNS-01, and NGINX enforces HTTPS. Helm schema validation provides governance, while a pre-install/pre-upgrade Job simulates database migrations."

## Common panel questions

### Why Helm subcharts?

They keep the tiers modular while preserving a single parent release and centralized enable/disable control.

### Why `values.schema.json`?

It validates Helm input before rendering and prevents invalid types or missing mandatory resource limits.

### Why Workload Identity?

It avoids storing long-lived Azure client secrets in application configuration.

### Why Key Vault?

It is the Azure source of truth for sensitive values.

### Why NetworkPolicy?

It restricts PostgreSQL network access to the API tier.

### Why PVC?

Database data must survive pod recreation.

### Why Ingress?

It provides one HTTP/HTTPS entry point and path-based routing.

### Why cert-manager?

It automates Let's Encrypt certificate issuance and renewal.

### Why Azure DNS?

It provides Azure-native DNS hosting and supports DNS-01 validation for cert-manager.

### Why PostgreSQL in AKS?

Because the assignment requires a containerized PostgreSQL database and PVC. In production, a managed Azure PostgreSQL service would normally be considered.

### Why a migration hook?

The assignment requires a pre-install/pre-upgrade migration simulation before the API rollout.
