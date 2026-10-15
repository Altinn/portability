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

variable "image" {
  type        = string
  description = "Container image, preferably an immutable digest"
}

variable "port" {
  type        = number
  description = "HTTP listen port"
  default     = 8080
}

variable "cpu_limit" {
  type        = number
  description = "CPU in milli-vCPU"
  default     = 560
}

variable "memory_limit_bytes" {
  type        = number
  description = "Memory bytes (matched to CPU)"
  default     = 1073000000
}

variable "min_scale" {
  type        = number
  description = "Minimum running replicas"
  default     = 0
}

variable "max_scale" {
  type        = number
  description = "Maximum replicas"
  default     = 1
}

variable "privacy" {
  type        = string
  description = "Scaleway invocation authentication"
  default     = "private"
  validation {
    condition     = contains(["private", "public"], var.privacy)
    error_message = "privacy must be private or public."
  }
}

variable "health_path" {
  type        = string
  description = "HTTP liveness path"
  default     = "/"
}

variable "environment_variables" {
  type        = map(string)
  description = "Non-secret environment values"
  default     = {}
}

variable "secret_environment_variables" {
  type        = map(string)
  description = "Sensitive environment values; stored in Terraform state"
  default     = {}
  sensitive   = true
}
