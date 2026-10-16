resource "scaleway_rdb_instance" "this" {
  name                      = var.name
  project_id                = var.project_id
  region                    = var.region
  tags                      = var.tags
  node_type                 = var.node_type
  engine                    = var.engine
  is_ha_cluster             = var.high_availability
  user_name                 = var.username
  password                  = var.password
  encryption_at_rest        = true
  disable_backup            = false
  backup_same_region        = true
  backup_schedule_frequency = 24
  backup_schedule_retention = 7
  volume_type               = "sbs_5k"
  volume_size_in_gb         = var.volume_size_gb

  settings = merge(
    {
      effective_cache_size            = "1300"
      maintenance_work_mem            = "150"
      max_connections                 = "100"
      max_parallel_workers            = "0"
      max_parallel_workers_per_gather = "0"
      work_mem                        = "4"
    },
    var.enable_pgaudit ? {
      "rdb.enable_pgaudit" = "true"
    } : {}
  )
  private_network {
    pn_id       = var.private_network_id
    enable_ipam = true
  }
  # No load_balancer block: private endpoint only.
}
resource "scaleway_rdb_database" "this" {
  instance_id = scaleway_rdb_instance.this.id
  name        = var.database_name
  region      = var.region
}

resource "scaleway_rdb_privilege" "application" {
  instance_id   = scaleway_rdb_instance.this.id
  database_name = scaleway_rdb_database.this.name
  user_name     = var.username
  permission    = "all"
  region        = var.region
}
