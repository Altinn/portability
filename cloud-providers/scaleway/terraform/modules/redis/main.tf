resource "scaleway_redis_cluster" "this" {
  name         = var.name
  project_id   = var.project_id
  zone         = var.zone
  tags         = var.tags
  version      = var.redis_version
  node_type    = var.node_type
  cluster_size = 1
  user_name    = var.username
  password     = var.password
  tls_enabled  = true
  private_network { id = var.private_network_id }
  # No public_network or ACL: private endpoint only, with IPAM.
}
