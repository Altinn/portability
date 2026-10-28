output "application_endpoint" {
  description = "Public application endpoints for Serverless Container and Kubernetes"

  value = {
    serverless_container = module.application.endpoint
    kubernetes = var.enable_kubernetes
      ? module.kubernetes_application[0].endpoint
      : null
  }
}

output "container_endpoint" {
  value       = module.application.endpoint
  description = "Public Serverless Container endpoint"
}

output "container_id" {
  value       = module.application.container_id
  description = "Serverless Container id"
}

output "kubernetes_cluster_id" {
  value = var.enable_kubernetes
    ? module.kubernetes_cluster[0].cluster_id
    : null

  description = "Kapsule cluster id; null when Kubernetes is disabled"
}

output "kubernetes_load_balancer_ip" {
  value = var.enable_kubernetes
    ? module.kubernetes_application[0].load_balancer_ip
    : null

  description = "Public LoadBalancer IP for the Kubernetes workload; null when Kubernetes is disabled"
}

output "kubernetes_endpoint" {
  value = var.enable_kubernetes
    ? module.kubernetes_application[0].endpoint
    : null

  description = "Public endpoint for the Kubernetes workload; null when Kubernetes is disabled"
}

output "registry_endpoint" {
  value = module.registry.endpoint
}

output "attachments_bucket" {
  value = module.attachments.bucket_name
}

output "private_network_id" {
  value = module.network.private_network_id
}

output "postgresql_endpoint" {
  value = {
    host     = module.postgresql.host
    port     = module.postgresql.port
    database = module.postgresql.database_name
  }
}

output "redis_endpoint" {
  value = {
    host = module.redis.host
    port = module.redis.port
  }
}

output "postgresql_ca_pem" {
  value = module.postgresql.certificate
}

output "redis_ca_pem" {
  value = module.redis.certificate
}

output "secret_ids" {
  value = module.secrets.secret_ids
}

output "runtime" {
  description = "Runtime and HTTP test configuration"

  value = {
    serverless_container = merge(
      module.application.runtime,
      {
        mode     = var.container_mode
        platform = "serverless-container"
      }
    )

    kubernetes = var.enable_kubernetes ? merge(
      module.kubernetes_application[0].runtime,
      {
        mode     = var.container_mode
        platform = "kubernetes"
      }
    ) : null
  }
}