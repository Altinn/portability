variable "name" {
  type        = string
  description = "Resource name"
}

variable "project_id" {
  type        = string
  description = "Scaleway project UUID"
}

variable "tags" {
  type        = list(string)
  description = "Resource tags"
  default     = []
}

variable "zone" {
  type        = string
  description = "Scaleway availability zone"
}

variable "private_network_id" {
  type        = string
  description = "Private Network regional ID"
}

variable "username" {
  type        = string
  description = "Redis username"
  default     = "pocuser"
}

variable "password" {
  type        = string
  description = "Redis password; stored in Terraform state"
  sensitive   = true
  validation {
    condition     = length(var.password) >= 16 && length(var.password) <= 128 && can(regex("^[A-Za-z0-9_-]+$", var.password)) && can(regex("[A-Z]", var.password)) && can(regex("[a-z]", var.password)) && can(regex("[0-9]", var.password)) && can(regex("[_-]", var.password))
    error_message = "Use 16-128 characters with uppercase, lowercase, a digit and underscore/hyphen; only A-Z, a-z, 0-9, _ and - are allowed."
  }
}

variable "redis_version" {
  type        = string
  description = "Redis engine version; check availability in the selected zone"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.redis_version))
    error_message = "Select an available patched Redis version, in major.minor.patch format."
  }
}

variable "node_type" {
  type        = string
  description = "Redis node type"
  default     = "RED1-MICRO"
}
