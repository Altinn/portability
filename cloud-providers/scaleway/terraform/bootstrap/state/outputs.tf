output "bucket_name" { value = scaleway_object_bucket.state.name }
output "s3_endpoint" { value = "https://s3.${var.region}.scw.cloud" }
