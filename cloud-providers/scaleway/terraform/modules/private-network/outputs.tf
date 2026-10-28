output "vpc_id" {
  value = local.vpc_id
}

output "private_network_id" {
  value = scaleway_vpc_private_network.this.id
}