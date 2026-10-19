locals {
  tags                       = ["application=correspondence", "environment=internal-poc", "managed-by=terraform"]
  bucket_tags                = { application = "correspondence", environment = "internal-poc", "managed-by" = "terraform" }
  bucket_name                = coalesce(var.attachments_bucket_name, "${var.name_prefix}-attachments-${substr(var.project_id, 0, 8)}")
  image                      = var.container_image != null ? var.container_image : "docker.io/nginxinc/nginx-unprivileged:1.28-alpine"
  database_connection_string = "Host=${module.postgresql.host};Port=${module.postgresql.port};Database=${module.postgresql.database_name};Username=${module.postgresql.username};Password=${var.database_password};SSL Mode=VerifyCA;Root Certificate=/app/certs/postgresql-ca.pem"
  # Verify the TLS server identity using Scaleway's CA/certificate when porting .NET Redis.
  #redis_connection_string = "${module.redis.host}:${module.redis.port},user=${module.redis.username},password=${var.redis_password},ssl=true,abortConnect=false"
  extra_secret_keys = toset(keys(var.application_secrets))
  #secret_names = setunion(toset(["database-connection-string", "redis-connection-string"]), var.application_secret_names)
  secret_names = setunion(toset(["database-connection-string"]), var.application_secret_names)
  secret_values = merge({
    "database-connection-string" = local.database_connection_string
  }, var.application_secrets)
  #"redis-connection-string"    = local.redis_connection_string
  probe_environment = {
    POSTGRES_HOST     = module.postgresql.host
    POSTGRES_PORT     = tostring(module.postgresql.port)
    POSTGRES_DATABASE = module.postgresql.database_name
    POSTGRES_USER     = module.postgresql.username
    POSTGRES_CA_PEM   = module.postgresql.certificate
    REDIS_HOST        = module.redis.host
    REDIS_PORT        = tostring(module.redis.port)
    REDIS_USER        = module.redis.username
    REDIS_PASSWORD    = var.redis_password
    REDIS_CA_PEM      = module.redis.certificate
    S3_ENDPOINT = module.attachments.endpoint
    S3_REGION   = var.region
    S3_BUCKET   = module.attachments.bucket_name
  }
}