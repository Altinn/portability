
output "container_endpoint" {
  value       = module.application.endpoint
  description = "Use X-Auth-Token when invocation privacy is private"
}

output "container_id" {
  value       = module.application.container_id
  description = ""
}

output "registry_endpoint" {
  value       = module.registry.endpoint
  description = ""
}

output "attachments_bucket" {
  value       = module.attachments.bucket_name
  description = ""
}

output "private_network_id" {
  value       = module.network.private_network_id
  description = ""
}

output "postgresql_endpoint" {
  value       = { host = module.postgresql.host, port = module.postgresql.port, database = module.postgresql.database_name }
  description = ""
}
/*
output "redis_endpoint" {
  value       = { host = module.redis.host, port = module.redis.port }
  description = ""
}
*/
output "postgresql_ca_pem" {
  value       = module.postgresql.certificate
  description = ""
}
/*
output "redis_ca_pem" {
  value       = module.redis.certificate
  description = ""
}
*/
output "secret_ids" {
  value       = module.secrets.secret_ids
  description = ""
}
/*
output "runtime" {
  description = "Runtime mode and HTTP test configuration"
  value       = merge(module.application.runtime, { mode = var.container_mode })
}
*/