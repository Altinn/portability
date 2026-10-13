resource "scaleway_secret" "this" {
  for_each   = var.secret_names
  name       = "${var.name}-${each.key}"
  project_id = var.project_id
  region     = var.region
  tags       = var.tags
  protected  = false
}
resource "scaleway_secret_version" "this" {
  for_each  = var.secret_names
  secret_id = scaleway_secret.this[each.key].id
  data      = var.secret_values[each.key]
  region    = var.region
}
