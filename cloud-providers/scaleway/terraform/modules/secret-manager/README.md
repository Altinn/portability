# secret-manager

Creates versioned secrets. Separate non-sensitive names allow sensitive values without using them as for_each keys. Values remain in Terraform state. Serverless Containers receive sensitive environment values; this provider resource has no Secret Manager reference input. Serverless Jobs can reference secret IDs.

Provider-specific building block. The caller sets names, sizing and application configuration.
Authentication is inherited from the root provider using `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`
and `SCW_DEFAULT_ORGANIZATION_ID`. See `variables.tf` for the complete input contract
and `outputs.tf` for the output contract.

Pinned provider documentation: https://registry.terraform.io/providers/scaleway/scaleway/2.86.0/docs
