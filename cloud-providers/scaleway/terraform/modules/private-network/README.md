# private-network

Creates a dedicated VPC and IPAM-managed Private Network. No public gateway is required for Serverless Containers.

Provider-specific building block. The caller sets names, sizing and application configuration.
Authentication is inherited from the root provider using `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`
and `SCW_DEFAULT_ORGANIZATION_ID`. See `variables.tf` for the complete input contract
and `outputs.tf` for the output contract.

Pinned provider documentation: https://registry.terraform.io/providers/scaleway/scaleway/2.86.0/docs
