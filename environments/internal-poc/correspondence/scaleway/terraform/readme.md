# Terraform – Altinn Correspondence Scaleway Internal PoC

This directory contains the Terraform configuration used to provision the Scaleway infrastructure required by the internal Altinn Correspondence portability PoC.

The configuration should remain simple and focused on the requirements of the PoC.

Reusable Scaleway-specific Terraform components should be placed under `cloud-providers/scaleway/terraform/` where appropriate.

Terraform state, credentials, and other sensitive information must not be committed to the repository.