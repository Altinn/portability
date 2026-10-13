output "secret_ids" {
  value       = { for name, secret in scaleway_secret.this : name => secret.id }
  description = ""
}

output "revisions" {
  value       = { for name, version in scaleway_secret_version.this : name => version.revision }
  description = ""
}
