resource "scaleway_vpc" "this" {
  count = var.vpc_id == null ? 1 : 0

  name           = "${var.name}-vpc"
  project_id     = var.project_id
  region         = var.region
  tags           = var.tags
  enable_routing = true
}

locals {
  vpc_id = var.vpc_id != null ? var.vpc_id : scaleway_vpc.this[0].id
}

resource "scaleway_vpc_private_network" "this" {
  name       = "${var.name}-pn"
  project_id = var.project_id
  region     = var.region
  vpc_id     = local.vpc_id
  tags       = var.tags

  ipv4_subnet {
    subnet = var.cidr
  }
}