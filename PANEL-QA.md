# Panel Q&A

## Architecture

### Q: Explain the architecture in 60 seconds.

A:
"The solution is a three-tier application on AKS. NGINX Ingress is the single external entry point. Azure DNS resolves the application hostname to the ingress public IP. NGINX routes `/` to the frontend and `/api` to the Node.js API. The API communicates with PostgreSQL over the internal Kubernetes network. PostgreSQL is backed by a PVC and protected by a NetworkPolicy allowing ingress only from API pods. Secrets are stored in Azure Key Vault and accessed using Microsoft Entra Workload Identity and the Secrets Store CSI Driver. cert-manager obtains and renews a Let's Encrypt certificate using Azure DNS DNS-01, and NGINX enforces HTTPS."

### Q: Why AKS?

A:
"AKS is Azure's managed Kubernetes service and integrates with Azure identity, Key Vault, networking, DNS and storage."

### Q: Why Kubernetes?

A:
"Kubernetes provides orchestration, service discovery, self-healing, rolling deployment, scaling, storage and network policy."

## Helm

### Q: Why parent and child charts?

A:
"The parent chart provides one release and centralized governance while frontend, API and PostgreSQL remain modular linked subcharts."

### Q: How do you disable a tier?

A:
"The parent dependency uses a Helm condition such as `condition: api.enabled`. Setting `api.enabled=false` disables that subchart. Parent templates also use `if` conditions for resources such as Ingress."

### Q: Why `values.schema.json`?

A:
"It validates Helm values before rendering and enforces required fields, resource limits and data types."

### Q: Why resource requests and limits?

A:
"Requests influence scheduling; limits cap resource consumption and reduce the risk of a workload consuming excessive node resources."

### Q: Why a Helm hook?

A:
"The assignment requires a migration simulation before API rollout. The migration Job uses `pre-install,pre-upgrade`."

### Q: What is the limitation of this migration design?

A:
"The POC migration is intentionally simulated. A real migration that needs the PostgreSQL Service should be orchestrated so the database is available before the migration executes; production designs may use a dedicated migration workflow or an explicitly ordered database/migration lifecycle."

## Security

### Q: Where are secrets?

A:
"Azure Key Vault."

### Q: Is Base64 encryption?

A:
"No. Base64 is encoding, not encryption."

### Q: Why Workload Identity?

A:
"It avoids static long-lived Azure credentials in pods and uses federated identity between Kubernetes and Microsoft Entra ID."

### Q: What does the CSI driver do?

A:
"It integrates Kubernetes volumes with the external secrets provider. The Azure provider retrieves Key Vault objects and can synchronize them into a Kubernetes Secret."

### Q: Why NetworkPolicy?

A:
"It restricts PostgreSQL ingress to API pods and reduces lateral movement and database exposure."

## Networking

### Q: Why ClusterIP for PostgreSQL?

A:
"The database does not need Internet exposure. ClusterIP keeps it internal to the cluster."

### Q: Why Ingress?

A:
"One external HTTP/HTTPS entry point can route multiple application paths without exposing each service separately."

## TLS/DNS

### Q: How is HTTPS automated?

A:
"cert-manager requests the Let's Encrypt certificate, stores it in a Kubernetes TLS Secret and renews it before expiry."

### Q: Why DNS-01?

A:
"It lets cert-manager prove domain control by creating an ACME TXT record in Azure DNS. It works cleanly with Azure DNS and avoids relying on an HTTP challenge endpoint."

### Q: Why Azure DNS?

A:
"The assignment is Azure-only, and Azure DNS provides authoritative DNS plus the DNS API needed by the cert-manager Azure DNS solver."

## Database

### Q: Why StatefulSet?

A:
"PostgreSQL is stateful and requires stable storage identity. The StatefulSet uses a PVC for persistent data."

### Q: Would you run PostgreSQL in AKS in production?

A:
"For this POC, yes, because the assignment requires containerized PostgreSQL and a PVC. For production, I would evaluate Azure Database for PostgreSQL for managed backups, HA, patching and operations."

## Live changes

### Disable frontend

```yaml
frontend:
  enabled: false
```

Then:

```bash
helm upgrade myapp . -n app
```

### Break schema

```yaml
api:
  enabled: "yes"
```

Then:

```bash
helm lint .
```

Expected: schema validation failure.

### Inspect resources

```bash
kubectl get pods -n app
kubectl get svc -n app
kubectl get pvc -n app
kubectl get networkpolicy -n app
kubectl get ingress -n app
kubectl get certificate -n app
kubectl get jobs -n app
```
