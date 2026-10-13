output "bucket_name" {
  value       = scaleway_object_bucket.this.name
  description = ""
}

output "endpoint" {
  value       = "https://s3.${var.region}.scw.cloud"
  description = ""
}
