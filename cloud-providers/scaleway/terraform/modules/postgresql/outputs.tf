output "instance_id" {
  value       = scaleway_rdb_instance.this.id
  description = ""
}

output "database_name" {
  value       = scaleway_rdb_database.this.name
  description = ""
}

output "username" {
  value       = var.username
  description = ""
}

output "host" {
  value       = scaleway_rdb_instance.this.private_network[0].ip
  description = ""
}

output "port" {
  value       = scaleway_rdb_instance.this.private_network[0].port
  description = ""
}

output "certificate" {
  value       = scaleway_rdb_instance.this.certificate
  description = "PostgreSQL CA PEM"
}
