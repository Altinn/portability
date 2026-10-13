# serverless-job

Defines a job only; Terraform does not execute it. Serverless Jobs currently do not support Private Networks, so this module cannot run migrations against the private PostgreSQL in this PoC. Execute database migration bundles on a VPC-connected runner. No private_network_id is invented.

Provider-specific building block. The caller sets names, sizing and application configuration.
Authentication is inherited from the root provider using `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`
and `SCW_DEFAULT_ORGANIZATION_ID`. See `variables.tf` for the complete input contract
and `outputs.tf` for the output contract.

Pinned provider documentation: https://registry.terraform.io/providers/scaleway/scaleway/2.86.0/docs
