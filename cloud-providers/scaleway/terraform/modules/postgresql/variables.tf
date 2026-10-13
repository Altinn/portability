variable "name" {
  type        = string
  description = "Resource name"
}

variable "project_id" {
  type        = string
  description = "Scaleway project UUID"
}

variable "region" {
  type        = string
  description = "Scaleway region"
}

variable "tags" {
  type        = list(string)
  description = "Resource tags"
  default     = []
}

variable "private_network_id" {
  type        = string
  description = "Private Network regional ID"
}

variable "database_name" {
  type        = string
  description = "Application database name"
}

variable "username" {
  type        = string
  description = "Initial database user"
  default     = "pocadmin"
}

variable "password" {
  type        = string
  description = "Database password; stored in Terraform state"
  sensitive   = true
  validation {
    condition     = length(var.password) >= 16 && length(var.password) <= 128 && can(regex("^[A-Za-z0-9_-]+$", var.password)) && can(regex("[A-Z]", var.password)) && can(regex("[a-z]", var.password)) && can(regex("[0-9]", var.password)) && can(regex("[_-]", var.password))
    error_message = "Use 16-128 characters: uppercase, lowercase, a digit and underscore/hyphen; only A-Z, a-z, 0-9, _ and - are allowed for safe connection string composition."
  }
}

variable "node_type" {
  type        = string
  description = "Managed database node type"
  default     = "DB-PLAY2-PICO"
}

variable "engine" {
  type        = string
  description = "Database engine"
  default     = "PostgreSQL-17"
}

variable "high_availability" {
  type        = bool
  description = "Enable HA"
  default     = false
}

variable "volume_size_gb" {
  type        = number
  description = "Block storage size in GB"
  default     = 10
}
