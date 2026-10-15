project_id        = "8a731d6e-cf59-4515-a092-7b8d211bed3a"
region            = "fr-par"
zone              = "fr-par-1"
name_prefix       = "altinn-corr-internal-poc"
redis_version     = "8.4.0"
container_mode    = "smoke"
container_privacy = "private"
min_scale         = 0

# DB and Redis incur ongoing cost even when min_scale = 0.
# Passwords come from TF_VAR_database_password and TF_VAR_redis_password.
# First deployment uses nginx; later use the built connectivity probe:
# container_mode = "connectivity"
# container_image = "rg.fr-par.scw.cloud/YOUR-NAMESPACE/connectivity:COMMIT-SHA"
# For the ported app (not the unchanged Azure image):
# container_mode = "correspondence"
# min_scale = 1
# container_image = "rg.fr-par.scw.cloud/YOUR-NAMESPACE/correspondence@sha256:..."
# application_secret_names = ["MaskinportenSettings__ClientId"]
# application_secrets must be passed separately, never committed.
