output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "service_name" {
  value = kubernetes_service_v1.public.metadata[0].name
}

output "load_balancer_ip" {
  value = try(kubernetes_service_v1.public.status[0].load_balancer[0].ingress[0].ip, null)
}

output "load_balancer_hostname" {
  value = try(kubernetes_service_v1.public.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "endpoint" {
  value = try(
    "http://${kubernetes_service_v1.public.status[0].load_balancer[0].ingress[0].ip}${var.public_port == 80 ? "" : ":${var.public_port}"}",
    null
  )
}

output "runtime" {
  value = {
    namespace   = kubernetes_namespace_v1.this.metadata[0].name
    replicas    = var.replicas
    pod_port    = var.container_port
    public_port = var.public_port
    health_path = var.health_path
  }
}
