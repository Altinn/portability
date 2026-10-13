output "cluster_id" {
  value       = scaleway_redis_cluster.this.id
  description = ""
}

output "host" {
  value       = one(scaleway_redis_cluster.this.private_network).ips[0]
  description = ""
}

output "port" {
  value       = one(scaleway_redis_cluster.this.private_network).port
  description = ""
}

output "username" {
  value       = var.username
  description = ""
}

output "certificate" {
  value       = scaleway_redis_cluster.this.certificate
  description = "Redis TLS CA PEM"
}
