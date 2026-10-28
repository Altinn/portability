
locals {
  tags        = ["application=correspondence", "environment=internal-poc", "managed-by=terraform"]
  bucket_tags = { application = "correspondence", environment = "internal-poc", "managed-by" = "terraform" }
  bucket_name = coalesce(var.attachments_bucket_name, "${var.name_prefix}-attachments-${substr(var.project_id, 0, 8)}")
  image       = var.container_image != null ? var.container_image : "docker.io/nginxinc/nginx-unprivileged:1.28-alpine"

  application_port        = var.container_mode == "correspondence" ? 2525 : 8080
  application_health_path = var.container_mode == "correspondence" ? "/health" : "/"

  database_connection_string = "Host=${module.postgresql.host};Port=${module.postgresql.port};Database=${module.postgresql.database_name};Username=${module.postgresql.username};Password=${var.database_password};SSL Mode=VerifyCA;Root Certificate=/app/certs/postgresql-ca.pem"
  redis_connection_string    = "${module.redis.host}:${module.redis.port},user=${module.redis.username},password=${var.redis_password},ssl=true,abortConnect=false"

  correspondence_secret_names = toset([
    "MaskinportenSettings__ClientId",
    "MaskinportenSettings__EncodedJwk",
    "AltinnOptions__PlatformSubscriptionKey",
    "AltinnOptions__AccessManagementSubscriptionKey",
    "AltinnIdProviderSettings__ClientId",
    "AltinnIdProviderSettings__ClientSecret",
    "GeneralSettings__CorrespondenceBaseUrl",
  ])
  extra_secret_keys = toset(keys(var.application_secrets))
  secret_names      = setunion(toset(["database-connection-string"]), var.application_secret_names)
  secret_values = merge({
    "database-connection-string" = local.database_connection_string
  }, var.application_secrets)

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
    S3_ENDPOINT       = module.attachments.endpoint
    S3_REGION         = var.region
    S3_BUCKET         = module.attachments.bucket_name
  }

  runtime_environment_variables = merge(
    var.container_mode == "connectivity" ? local.probe_environment : {},
    var.container_mode == "correspondence" ? {
      ASPNETCORE_URLS                          = "http://+:2525"
      ASPNETCORE_ENVIRONMENT                   = "ScalewayPoc"
      MaskinportenJwkRotationSettings__Enabled = "false"
      AttachmentStorageOptions__S3Endpoint     = module.attachments.endpoint
      AttachmentStorageOptions__S3Bucket       = module.attachments.bucket_name
      AttachmentStorageOptions__S3Region       = var.region
    } : {},
    var.application_environment
  )

  runtime_secret_environment_variables = var.container_mode == "smoke" ? {} : merge(
    var.container_mode == "connectivity" ? {
      POSTGRES_PASSWORD = var.database_password
      REDIS_PASSWORD    = var.redis_password
      S3_ACCESS_KEY     = var.s3_access_key
      S3_SECRET_KEY     = var.s3_secret_key
    } : {},
    var.container_mode == "correspondence" ? {
      DatabaseOptions__ConnectionString      = local.database_connection_string
      DatabaseOptions__SslRootCertificatePem = module.postgresql.certificate
      GeneralSettings__RedisConnectionString = local.redis_connection_string
      GeneralSettings__RedisCaPem            = module.redis.certificate
      AttachmentStorageOptions__S3AccessKey  = var.s3_access_key
      AttachmentStorageOptions__S3SecretKey  = var.s3_secret_key
    } : {},
    var.application_secrets
  )
}
