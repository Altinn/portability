
output "application_endpoint" {
  value       = var.application_runtime == "serverless-container" ? module.application.endpoint : module.kubernetes_application.endpoint
  description = "Public application endpoint for the selected runtime"
}

output "container_endpoint" {
  value       = var.application_runtime == "serverless-container" ? module.application.endpoint : null
  description = "Serverless Container endpoint; null when Kubernetes is selected"
}

output "container_id" {
  value       = var.application_runtime == "serverless-container" ? module.application.container_id : null
  description = "Serverless Container id; null when Kubernetes is selected"
}

output "kubernetes_cluster_id" {
  value       = var.application_runtime == "kubernetes" ? module.kubernetes_cluster.cluster_id : null
  description = "Kapsule cluster id; null when Serverless Container is selected"
}

output "kubernetes_load_balancer_ip" {
  value       = var.application_runtime == "kubernetes" ? module.kubernetes_application.load_balancer_ip : null
  description = "Public LoadBalancer IP for the Kubernetes workload"
}

output "registry_endpoint" { value = module.registry.endpoint }
output "attachments_bucket" { value = module.attachments.bucket_name }
output "private_network_id" { value = module.network.private_network_id }
output "postgresql_endpoint" { value = { host = module.postgresql.host, port = module.postgresql.port, database = module.postgresql.database_name } }
output "redis_endpoint" { value = { host = module.redis.host, port = module.redis.port } }
output "postgresql_ca_pem" { value = module.postgresql.certificate }
output "redis_ca_pem" { value = module.redis.certificate }
output "secret_ids" { value = module.secrets.secret_ids }

output "runtime" {
  description = "Selected runtime and HTTP test configuration"
  value = var.application_runtime == "serverless-container" ? merge(
    module.application[0].runtime,
    { mode = var.container_mode, platform = "serverless-container" }
    ) : merge(
    module.kubernetes_application[0].runtime,
    { mode = var.container_mode, platform = "kubernetes" }
  )
}
