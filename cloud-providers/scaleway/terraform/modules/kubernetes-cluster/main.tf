resource "scaleway_k8s_cluster" "this" {
  name                        = var.name
  project_id                  = var.project_id
  region                      = var.region
  type                        = "kapsule"
  version                     = var.kubernetes_version
  cni                         = "cilium"
  private_network_id          = var.private_network_id
  delete_additional_resources = var.delete_additional_resources
  tags                        = var.tags
}

resource "scaleway_k8s_pool" "this" {
  cluster_id          = scaleway_k8s_cluster.this.id
  version             = scaleway_k8s_cluster.this.version
  name                = "applications"
  node_type           = var.node_type
  zone                = var.zone
  region              = var.region
  size                = var.pool_size
  min_size            = var.min_size
  max_size            = var.max_size
  autoscaling         = var.autoscaling
  autohealing         = true
  public_ip_disabled  = false
  wait_for_pool_ready = true
}
