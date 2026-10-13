resource "scaleway_container_namespace" "this" {
  name       = "${var.name}-ns"
  project_id = var.project_id
  region     = var.region
  tags       = var.tags
}
resource "scaleway_container" "this" {
  name                         = var.name
  namespace_id                 = scaleway_container_namespace.this.id
  region                       = var.region
  tags                         = var.tags
  image                        = var.image
  port                         = var.port
  cpu_limit                    = var.cpu_limit
  memory_limit_bytes           = var.memory_limit_bytes
  min_scale                    = var.min_scale
  max_scale                    = var.max_scale
  privacy                      = var.privacy
  protocol                     = "http1"
  https_connections_only       = true
  timeout                      = 300
  private_network_id           = var.private_network_id
  environment_variables        = var.environment_variables
  secret_environment_variables = var.secret_environment_variables
  liveness_probe {
    http { path = var.health_path }
    failure_threshold = 3
    interval          = "30s"
    timeout           = "5s"
  }
}
