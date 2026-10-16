provider "scaleway" {
  #project_id = var.project_id
  region     = var.region
  zone       = var.zone
  # Authentication comes only from SCW_* environment variables.
}
