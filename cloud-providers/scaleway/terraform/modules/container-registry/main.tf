resource "scaleway_registry_namespace" "this" {
  name        = var.name
  project_id  = var.project_id
  region      = var.region
  is_public   = false
  description = "Terraform-managed private container registry"
}
