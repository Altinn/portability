project_id          = "8a731d6e-cf59-4515-a092-7b8d211bed3a"
region              = "pl-waw"
zone                = "pl-waw-1"
name_prefix         = "altinn-corr-internal-poc"
redis_version       = "8.4.0"
application_runtime = "serverless-container"
container_mode      = "smoke"
container_privacy   = "private"
min_scale           = 0

# DB and Redis incur ongoing cost even when min_scale = 0.
# Passwords come from TF_VAR_database_password and TF_VAR_redis_password.
# First deployment uses nginx; later use the built connectivity probe:
# container_mode = "connectivity"
# container_image = "rg.fr-par.scw.cloud/YOUR-NAMESPACE/connectivity:COMMIT-SHA"
# Correspondence deploy (set the same non-secret fields in GitHub SCW_TFVARS_JSON):
# container_mode = "correspondence"
# container_privacy = "public"
# min_scale = 1
# container_image = "rg.pl-waw.scw.cloud/YOUR-NAMESPACE/correspondence@sha256:..."
# application_secret_names = [
#   "MaskinportenSettings__ClientId",
#   "MaskinportenSettings__EncodedJwk",
#   "AltinnOptions__PlatformSubscriptionKey",
#   "AltinnOptions__AccessManagementSubscriptionKey",
#   "AltinnIdProviderSettings__ClientId",
#   "AltinnIdProviderSettings__ClientSecret",
#   "GeneralSettings__CorrespondenceBaseUrl",
# ]
# Put the matching TT02 values in POC_APPLICATION_SECRETS_JSON. Never commit them.


# Kubernetes alternative (same PostgreSQL/Redis/attachment resources):
# application_runtime       = "kubernetes"
# kubernetes_version        = "1.37.1"
# kubernetes_node_type      = "DEV1-M"
# kubernetes_pool_size      = 1
# kubernetes_min_size       = 1
# kubernetes_max_size       = 2
# kubernetes_autoscaling    = false
# kubernetes_replicas       = 1
# kubernetes_public_port    = 80
# container_mode            = "correspondence"
# container_image           = "rg.pl-waw.scw.cloud/YOUR-NAMESPACE/correspondence@sha256:..."
# registry_pull_secret comes from TF_VAR_registry_pull_secret and must not be committed.
