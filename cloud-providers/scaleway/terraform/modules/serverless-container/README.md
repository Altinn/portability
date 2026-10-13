# serverless-container

Creates a Private Network-attached HTTP container. Private invocation requires X-Auth-Token; it is distinct from network attachment. Scale-to-zero is the initial default; background workers need min_scale >= 1 after application porting.

Provider-specific building block. The caller sets names, sizing and application configuration.
Authentication is inherited from the root provider using `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`
and `SCW_DEFAULT_ORGANIZATION_ID`. See `variables.tf` for the complete input contract
and `outputs.tf` for the output contract.

Pinned provider documentation: https://registry.terraform.io/providers/scaleway/scaleway/2.86.0/docs
