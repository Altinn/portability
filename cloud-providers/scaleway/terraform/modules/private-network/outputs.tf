output "vpc_id" {
  value       = scaleway_vpc.this.id
  description = ""
}

output "private_network_id" {
  value       = scaleway_vpc_private_network.this.id
  description = ""
}
