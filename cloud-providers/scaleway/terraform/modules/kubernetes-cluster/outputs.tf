output "cluster_id" {
  value = scaleway_k8s_cluster.this.id
}

output "pool_id" {
  value = scaleway_k8s_pool.this.id
}

output "wildcard_dns" {
  value = scaleway_k8s_cluster.this.wildcard_dns
}

output "kubeconfig" {
  sensitive = true
  value = {
    host                   = scaleway_k8s_cluster.this.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.this.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.this.kubeconfig[0].cluster_ca_certificate
  }
  depends_on = [scaleway_k8s_pool.this]
}
