variable "postgresql_bootstrap_image" {
  type        = string
  default     = ""
  description = "Built PostgreSQL bootstrap image; empty disables deployment."
}

module "postgresql_bootstrap" {
  count = var.postgresql_bootstrap_image != "" ? 1 : 0

  source             = "../../../../../cloud-providers/scaleway/terraform/modules/serverless-container"
  name               = "${var.name_prefix}-pg-init"
  project_id         = var.project_id
  region             = var.region
  tags               = local.tags
  private_network_id = module.network.private_network_id
  image              = var.postgresql_bootstrap_image
  port               = 8080
  health_path        = "/health"
  privacy            = "private"
  min_scale          = 0
  max_scale          = 1
  memory_limit_bytes = 1073000000

  environment_variables = {
    POSTGRES_HOST     = module.postgresql.host
    POSTGRES_PORT     = tostring(module.postgresql.port)
    POSTGRES_DATABASE = module.postgresql.database_name
    POSTGRES_USER     = module.postgresql.username
    POSTGRES_CA_PEM   = module.postgresql.certificate
  }

  secret_environment_variables = {
    POSTGRES_PASSWORD = var.database_password
  }

  # Includes the database and its privilege resources within that module.
  depends_on = [module.postgresql]
}

output "postgresql_bootstrap_endpoint" {
  description = "Private-authenticated bootstrap endpoint used by the manual workflow."
  value       = try(module.postgresql_bootstrap[0].endpoint, "")
}
