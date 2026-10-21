module "network" {
  source     = "../../../../../cloud-providers/scaleway/terraform/modules/private-network"
  name       = var.name_prefix
  project_id = var.project_id
  region     = var.region
  cidr       = var.network_cidr
  tags       = local.tags
}

module "postgresql" {
  source             = "../../../../../cloud-providers/scaleway/terraform/modules/postgresql"
  name               = "${var.name_prefix}-postgres"
  project_id         = var.project_id
  region             = var.region
  tags               = local.tags
  private_network_id = module.network.private_network_id
  database_name      = "correspondence"
  password           = var.database_password
  engine             = var.postgresql_engine
  node_type          = var.postgresql_node_type
  enable_pgaudit     = true
}


module "redis" {
  source             = "../../../../../cloud-providers/scaleway/terraform/modules/redis"
  name               = "${var.name_prefix}-redis"
  project_id         = var.project_id
  zone               = var.zone
  tags               = local.tags
  private_network_id = module.network.private_network_id
  password           = var.redis_password
  redis_version      = var.redis_version
  node_type          = var.redis_node_type
}

module "attachments" {
  source        = "../../../../../cloud-providers/scaleway/terraform/modules/object-storage"
  name          = local.bucket_name
  project_id    = var.project_id
  region        = var.region
  tags          = local.bucket_tags
  force_destroy = var.force_destroy_attachments
}

module "secrets" {
  source        = "../../../../../cloud-providers/scaleway/terraform/modules/secret-manager"
  name          = var.name_prefix
  project_id    = var.project_id
  region        = var.region
  tags          = local.tags
  secret_names  = local.secret_names
  secret_values = local.secret_values
}

module "registry" {
  source     = "../../../../../cloud-providers/scaleway/terraform/modules/container-registry"
  name       = "${var.name_prefix}-registry"
  project_id = var.project_id
  region     = var.region
}


module "application" {
  source             = "../../../../../cloud-providers/scaleway/terraform/modules/serverless-container"
  name               = "${var.name_prefix}-api"
  project_id         = var.project_id
  region             = var.region
  tags               = local.tags
  private_network_id = module.network.private_network_id
  image              = local.image
  port               = var.container_mode == "correspondence" ? 2525 : 8080
  health_path        = var.container_mode == "correspondence" ? "/health" : "/"
  privacy            = var.container_privacy
  min_scale          = var.min_scale
  max_scale          = 1
  # 560 mVCPU / ~1 GiB is the nginx size. Correspondence keeps the PoC worker counts and still needs the next tier.
  cpu_limit          = var.container_mode == "correspondence" ? 1120 : 560
  memory_limit_bytes = var.container_mode == "correspondence" ? 2048000000 : 1073000000
  environment_variables = merge(
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
  secret_environment_variables = var.container_mode == "smoke" ? {} : merge(
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
  depends_on = [module.secrets, terraform_data.configuration_guard]
}

resource "terraform_data" "configuration_guard" {
  lifecycle {
    precondition {
      condition     = var.container_mode == "smoke" || var.container_image != null
      error_message = "Supply a built image for connectivity or correspondence mode."
    }
    precondition {
      condition     = var.container_mode != "correspondence" || var.min_scale >= 1
      error_message = "Correspondence background workers require min_scale >= 1."
    }
    precondition {
      condition     = !contains(["connectivity", "correspondence"], var.container_mode) || (var.s3_access_key != "" && var.s3_secret_key != "")
      error_message = "Connectivity and correspondence modes need the separate attachment-bucket S3 key, not the Terraform admin key."
    }
    precondition {
      condition = var.container_mode != "correspondence" || alltrue([
        for name in local.correspondence_secret_names :
        contains(var.application_secret_names, name) && length(trimspace(try(var.application_secrets[name], ""))) > 0
      ])
      error_message = "Correspondence mode requires non-empty TT02 secrets, including GeneralSettings__CorrespondenceBaseUrl once the container URL exists."
    }
    precondition {
      condition     = local.extra_secret_keys == var.application_secret_names
      error_message = "application_secret_names must exactly match application_secrets keys."
    }
    precondition {
      condition     = length(setintersection(var.application_secret_names, toset(["database-connection-string", "redis-connection-string"]))) == 0
      error_message = "Extra secrets cannot override generated connection-string secrets."
    }
  }
}
