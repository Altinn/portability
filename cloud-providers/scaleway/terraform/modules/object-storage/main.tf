resource "scaleway_object_bucket" "this" {
  name          = var.name
  project_id    = var.project_id
  region        = var.region
  tags          = var.tags
  force_destroy = var.force_destroy
  versioning { enabled = var.versioning_enabled }
}
