resource "scaleway_job_definition" "this" {
  name                   = var.name
  project_id             = var.project_id
  region                 = var.region
  image_uri              = var.image
  cpu_limit              = var.cpu_limit
  memory_limit           = var.memory_limit_mb
  local_storage_capacity = var.local_storage_capacity_mib
  timeout                = var.timeout
  startup_command        = var.startup_command
  args                   = var.args
  env                    = var.environment_variables
  dynamic "secret_reference" {
    for_each = var.secret_references
    content {
      secret_id      = secret_reference.value.secret_id
      secret_version = secret_reference.value.secret_version
      environment    = secret_reference.key
    }
  }
}
