# State bootstrap

Create a versioned, private Object Storage bucket before the PoC root is initialized.
This root uses local state and explicitly prevents deletion of the bucket.

1. Install Terraform 1.13.5.
2. Export `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`, `SCW_DEFAULT_ORGANIZATION_ID`.
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in the Digdir project,
   bucket name, region and zone. Never add credentials to that file.
4. Run `terraform init`, `terraform plan`, then `terraform apply`.
5. Preserve `terraform.tfstate` and its backup securely outside Git.
6. Use the bucket output for the PoC's backend or GitHub variable `SCW_STATE_BUCKET`.

Keep bootstrap state until the state bucket is imported into another controlled
platform stack. Do not delete the bootstrap state, run this root as part of PoC
cleanup, or remove `prevent_destroy` simply to tear down Correspondence.
Existing bucket: import it with `terraform import scaleway_object_bucket.state REGION/BUCKET`.
