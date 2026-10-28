variable "project_id" {
  type        = string
  description = "Digdir-owned Scaleway project UUID"
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.project_id))
    error_message = "Provide a Scaleway project UUID."
  }
}

variable "region" {
  type        = string
  description = "Region for all regional services"
  default     = "pl-waw"
}

variable "zone" {
  type        = string
  description = "Redis zone in the chosen region"
  default     = "pl-waw-1"
  validation {
    condition     = var.zone == "${var.region}-1"
    error_message = "Use the primary zone of the selected region (for example pl-waw-1)."
  }
}

variable "name_prefix" {
  type        = string
  description = "Lowercase resource prefix"
  default     = "altinn-corr-internal-poc"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,39}$", var.name_prefix))
    error_message = "Use 3-40 lowercase letters, digits and hyphens; start with a letter."
  }
}

variable "network_cidr" {
  type        = string
  description = "Private IPv4 subnet"
  default     = "10.20.0.0/24"
}

variable "database_password" {
  type        = string
  description = "Initial PostgreSQL password via TF_VAR_database_password"
  sensitive   = true
}

variable "redis_password" {
  type        = string
  description = "Redis password via TF_VAR_redis_password"
  sensitive   = true
}

variable "postgresql_node_type" {
  type        = string
  description = "PoC database size"
  default     = "DB-PLAY2-PICO"
}

variable "postgresql_engine" {
  type        = string
  description = "Database engine"
  default     = "PostgreSQL-17"
}

variable "redis_node_type" {
  type        = string
  description = "PoC Redis size"
  default     = "RED1-MICRO"
}

variable "redis_version" {
  type        = string
  description = "Redis engine version"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.redis_version))
    error_message = "Select an available patched Redis version, in major.minor.patch format."
  }
}

variable "attachments_bucket_name" {
  type        = string
  description = "Globally unique bucket name; null adds project UUID suffix"
  default     = null
}

variable "force_destroy_attachments" {
  type        = bool
  description = "Allow deletion of non-empty attachment bucket"
  default     = false
}

variable "container_mode" {
  type        = string
  description = "smoke = nginx, connectivity = supplied probe image, correspondence = ported app"
  default     = "smoke"
  validation {
    condition     = contains(["smoke", "connectivity", "correspondence"], var.container_mode)
    error_message = "Use smoke, connectivity or correspondence."
  }
}

variable "container_image" {
  type        = string
  description = "Override image; required for connectivity/correspondence"
  default     = null
}

variable "container_privacy" {
  type        = string
  description = "Scaleway invocation authentication"
  default     = "private"
}

variable "min_scale" {
  type        = number
  description = "Minimum replicas; use >=1 for Correspondence background work"
  default     = 0
}

variable "application_environment" {
  type        = map(string)
  description = "Additional non-secret application configuration"
  default     = {}
}

variable "application_secrets" {
  type        = map(string)
  description = "Extra sensitive environment values, including approved test integrations"
  default     = {}
  sensitive   = true
}

variable "application_secret_names" {
  type        = set(string)
  description = "Non-sensitive keys of application_secrets. Correspondence mode requires the TT02 names in local.correspondence_secret_names."
  default     = []
}

variable "s3_access_key" {
  type        = string
  description = "Separate attachment-bucket access key for the connectivity probe and Correspondence. Not the Terraform admin key."
  default     = ""
  sensitive   = true
}

variable "s3_secret_key" {
  type        = string
  description = "Separate attachment-bucket secret key for the connectivity probe and Correspondence. Not the Terraform admin key."
  default     = ""
  sensitive   = true
}

variable "application_runtime" {
  type        = string
  description = "Runtime for the application: serverless-container or kubernetes"
  default     = "serverless-container"
  validation {
    condition     = contains(["serverless-container", "kubernetes"], var.application_runtime)
    error_message = "Use serverless-container or kubernetes."
  }
}

variable "kubernetes_version" {
  type        = string
  description = "Kapsule Kubernetes version"
  default     = "1.37.1"
}

variable "kubernetes_node_type" {
  type        = string
  description = "Kapsule worker node type"
  default     = "DEV1-M"
}

variable "kubernetes_pool_size" {
  type        = number
  description = "Initial worker count"
  default     = 1
}

variable "kubernetes_min_size" {
  type        = number
  description = "Minimum worker count when autoscaling is enabled"
  default     = 1
}

variable "kubernetes_max_size" {
  type        = number
  description = "Maximum worker count when autoscaling is enabled"
  default     = 2
}

variable "kubernetes_autoscaling" {
  type        = bool
  description = "Enable Kapsule node-pool autoscaling"
  default     = false
}

variable "kubernetes_namespace" {
  type        = string
  description = "Namespace for the PoC workload"
  default     = "correspondence"
}

variable "kubernetes_replicas" {
  type        = number
  description = "Correspondence pod replicas"
  default     = 1
}

variable "kubernetes_public_port" {
  type        = number
  description = "Public LoadBalancer service port"
  default     = 80
}

variable "registry_pull_secret" {
  type        = string
  description = "Dedicated Scaleway Registry read credential used by Kapsule imagePullSecret"
  default     = ""
  sensitive   = true
}
