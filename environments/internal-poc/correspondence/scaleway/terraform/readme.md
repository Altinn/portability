# Correspondence internal PoC on Scaleway

This root composes the provider-specific modules from the exact repository paths
requested for the portability repository. Start with `container_mode = "smoke"`.

See the repository [README](../../../../../README.md) for GitHub setup, state bootstrap,
the connectivity probe and application-porting requirements.
[Norwegian quick start](../../../../../START_HER_NO.md) provides the import/run sequence.

## Local commands

```bash
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Edit project_id, bucket, region and zone. Never commit these local files.
# Export SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_ORGANIZATION_ID.
# Export TF_VAR_database_password and TF_VAR_redis_password from your secret store.
export AWS_ACCESS_KEY_ID="$SCW_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SCW_SECRET_KEY"
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=run.tfplan
terraform apply run.tfplan
terraform output
```

Local provider checks before credentials are available:

```bash
terraform init -backend=false
terraform validate
terraform test
```

The mock tests do not create cloud resources. `plan` with the real provider needs
valid IAM credentials and the state bucket; `apply` creates billable resources.
The runtime probe additionally tests private data-plane connectivity.

Root defaults: Paris (`fr-par` / `fr-par-1`), PostgreSQL 16 on `DB-DEV-S`,
an explicitly selected patched Redis version on `RED1-MICRO`, no HA, seven-day database backups,
private Redis with TLS, versioned private attachment storage, private registry,
and nginx on port 8080 with authenticated invocation and max one replica.
Verify SKU/version availability and quotas in the actual project before apply.

No Serverless Job is connected to the private database. Correspondence on
`ScalewayPoc` applies EF migrations during process startup. The standalone job
module remains for reachable non-private workloads.


## Kubernetes alternative

Set `application_runtime = "kubernetes"` to replace the Serverless Container
runtime with a Scaleway Kapsule cluster. PostgreSQL, Redis, Object Storage,
Secret Manager, Registry and the existing Private Network are reused.

Kapsule is attached to the same Private Network as PostgreSQL/Redis. A Kubernetes
`LoadBalancer` Service exposes a public IP on port 80 and forwards traffic to the
application pod (`2525` in Correspondence mode). The Scaleway CCM owns the
resulting Load Balancer; do not edit it manually in the Scaleway console.

The Warsaw Object Storage bucket is private at the IAM/bucket level, but Object
Storage private VPC endpoints are currently only available in Paris. Pods in
Warsaw therefore use the existing public regional S3 endpoint for data-plane
traffic.

For private Registry images, configure GitHub secret `POC_REGISTRY_PULL_SECRET`
with a dedicated credential that can read the registry. The Kubernetes image
pull secret is stored in Terraform state, so do not reuse the Terraform
administrative API key for this purpose.

Example non-secret `SCW_TFVARS_JSON` fields:

```json
{
  "application_runtime": "kubernetes",
  "container_mode": "correspondence",
  "container_image": "rg.pl-waw.scw.cloud/NAMESPACE/correspondence@sha256:...",
  "kubernetes_version": "1.37.1",
  "kubernetes_node_type": "DEV1-M",
  "kubernetes_pool_size": 1,
  "kubernetes_replicas": 1,
  "kubernetes_public_port": 80
}
```

The Kubernetes provider is configured from the Kapsule kubeconfig. On the very
first creation Terraform may need the cluster/pool to exist before it can create
Kubernetes API resources. If the first full apply cannot initialize the
Kubernetes provider, create the cluster module first and then rerun the normal
plan/apply. Subsequent updates are handled in the normal run.

### Recommended first Kubernetes deployment

Use two Terraform runs the first time Kubernetes is introduced:

1. Create the Kapsule cluster and node pool first if the Kubernetes provider cannot
   connect during the initial full apply:

   ```bash
   terraform apply -target=module.kubernetes_cluster
   ```

2. Run the normal `terraform plan` / `terraform apply` with
   `application_runtime = "kubernetes"`. For the simplest connectivity test, use
   `container_mode = "smoke"` first. After the public Load Balancer IP is known,
   switch to the Correspondence image and application secrets.

For Correspondence, set `GeneralSettings__CorrespondenceBaseUrl` to the intended
public URL before the final application apply. A DNS name/TLS endpoint can be
introduced later without changing the internal Service-to-pod routing model.

The existing Private Network CIDR is intentionally not changed by this addition.
Changing it in the same change set could recreate shared network/data resources.
Validate that the current subnet has sufficient address space for Kapsule before
creating the cluster; expand/migrate the network as a separate, reviewed change if
needed.
