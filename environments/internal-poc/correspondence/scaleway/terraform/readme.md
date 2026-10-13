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

No Serverless Job is connected to the private database. Use a VPC-connected
migration runner; the standalone job module is for reachable non-private workloads.
