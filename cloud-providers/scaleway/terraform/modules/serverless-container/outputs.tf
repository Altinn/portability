output "container_id" {
  value       = scaleway_container.this.id
  description = ""
}

output "endpoint" {
  value       = scaleway_container.this.public_endpoint
  description = ""
}

output "runtime" {
  description = "Runtime configuration to guide deployment checks"
  value = {
    port        = scaleway_container.this.port
    privacy     = scaleway_container.this.privacy
    min_scale   = scaleway_container.this.min_scale
    max_scale   = scaleway_container.this.max_scale
    health_path = var.health_path
  }
}
