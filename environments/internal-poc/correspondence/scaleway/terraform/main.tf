
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
  count  = var.application_runtime == "serverless-container" ? 1 : 0
  source = "../../../../../cloud-providers/scaleway/terraform/modules/serverless-container"

  name               = "${var.name_prefix}-api"
  project_id         = var.project_id
  region             = var.region
  tags               = local.tags
  private_network_id = module.network.private_network_id
  image              = local.image
  port               = local.application_port
  health_path        = local.application_health_path
  privacy            = var.container_privacy
  min_scale          = var.min_scale
  max_scale          = 1
  cpu_limit          = var.container_mode == "correspondence" ? 1120 : 560
  memory_limit_bytes = var.container_mode == "correspondence" ? 2048000000 : 1073000000
  environment_variables        = local.runtime_environment_variables
  secret_environment_variables = local.runtime_secret_environment_variables
  depends_on = [module.secrets, terraform_data.configuration_guard]
}

module "kubernetes_cluster" {
  count  = var.application_runtime == "kubernetes" ? 1 : 0
  source = "../../../../../cloud-providers/scaleway/terraform/modules/kubernetes-cluster"

  name               = "${var.name_prefix}-k8s"
  project_id         = var.project_id
  region             = var.region
  zone               = var.zone
  private_network_id = module.network.private_network_id
  tags               = local.tags
  kubernetes_version = var.kubernetes_version
  node_type          = var.kubernetes_node_type
  pool_size          = var.kubernetes_pool_size
  min_size           = var.kubernetes_min_size
  max_size           = var.kubernetes_max_size
  autoscaling        = var.kubernetes_autoscaling
}

module "kubernetes_application" {
  count  = var.application_runtime == "kubernetes" ? 1 : 0
  source = "../../../../../cloud-providers/scaleway/terraform/modules/kubernetes-application"
  providers = {
    kubernetes = kubernetes.kapsule
  }

  name                         = "${var.name_prefix}-api"
  namespace                    = var.kubernetes_namespace
  image                        = local.image
  container_port               = local.application_port
  public_port                  = var.kubernetes_public_port
  health_path                  = local.application_health_path
  replicas                     = var.kubernetes_replicas
  environment_variables        = local.runtime_environment_variables
  secret_environment_variables = local.runtime_secret_environment_variables
  cpu_request                  = var.container_mode == "correspondence" ? "500m" : "100m"
  cpu_limit                    = var.container_mode == "correspondence" ? "1100m" : "500m"
  memory_request               = var.container_mode == "correspondence" ? "1Gi" : "128Mi"
  memory_limit                 = var.container_mode == "correspondence" ? "2Gi" : "512Mi"
  create_registry_pull_secret  = var.container_mode != "smoke"
  registry_server              = split("/", module.registry.endpoint)[0]
  registry_username            = "${var.name_prefix}-registry"
  registry_password            = var.registry_pull_secret

  depends_on = [module.kubernetes_cluster, module.secrets, terraform_data.configuration_guard]
}

resource "terraform_data" "configuration_guard" {
  lifecycle {
    precondition {
      condition     = var.container_mode == "smoke" || var.container_image != null
      error_message = "Supply a built image for connectivity or correspondence mode."
    }
    precondition {
      condition     = var.container_mode != "correspondence" || (var.application_runtime == "serverless-container" ? var.min_scale >= 1 : var.kubernetes_replicas >= 1)
      error_message = "Correspondence requires at least one continuously running instance/pod."
    }
    precondition {
      condition     = !contains(["connectivity", "correspondence"], var.container_mode) || (var.s3_access_key != "" && var.s3_secret_key != "")
      error_message = "Connectivity and correspondence modes need the separate attachment-bucket S3 key, not the Terraform admin key."
    }
    precondition {
      condition     = var.application_runtime != "kubernetes" || var.container_mode == "smoke" || var.registry_pull_secret != ""
      error_message = "Kubernetes with a private registry image requires TF_VAR_registry_pull_secret. Use a dedicated read-only registry API key."
    }
    precondition {
      condition = var.container_mode != "correspondence" || alltrue([
        for name in local.correspondence_secret_names :
        contains(var.application_secret_names, name) && length(trimspace(try(var.application_secrets[name], ""))) > 0
      ])
      error_message = "Correspondence mode requires non-empty TT02 secrets, including GeneralSettings__CorrespondenceBaseUrl once the public endpoint exists."
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
