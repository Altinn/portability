resource "scaleway_vpc" "this" {
  name           = "${var.name}-vpc"
  project_id     = var.project_id
  region         = var.region
  tags           = var.tags
  enable_routing = true
}
resource "scaleway_vpc_private_network" "this" {
  name       = "${var.name}-pn"
  project_id = var.project_id
  region     = var.region
  vpc_id     = scaleway_vpc.this.id
  tags       = var.tags
  ipv4_subnet { subnet = var.cidr }
}
