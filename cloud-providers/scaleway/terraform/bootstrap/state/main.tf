resource "scaleway_object_bucket" "state" {
  name          = var.bucket_name
  project_id    = var.project_id
  region        = var.region
  force_destroy = false
  versioning { enabled = true }
  tags = { purpose = "terraform-state", owner = "digdir", "managed-by" = "terraform" }
  lifecycle { prevent_destroy = true }
}
# Local state is deliberately used for one-time bootstrap. Preserve it securely.
# The state bucket lifecycle has stronger deletion protection than ordinary data buckets.
