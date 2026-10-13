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

variable "image" {
  type        = string
  description = "Job image"
}

variable "cpu_limit" {
  type        = number
  description = "CPU in milli-vCPU"
  default     = 560
}

variable "memory_limit_mb" {
  type        = number
  description = "Memory in MB"
  default     = 1024
}

variable "local_storage_capacity_mib" {
  type        = number
  description = "Local storage in MiB"
  default     = 1024
}

variable "timeout" {
  type        = string
  description = "Maximum run duration"
  default     = "10m"
}

variable "startup_command" {
  type        = list(string)
  description = "Override image entrypoint"
  default     = null
}

variable "args" {
  type        = list(string)
  description = "Override image arguments"
  default     = null
}

variable "environment_variables" {
  type        = map(string)
  description = "Non-secret environment values"
  default     = {}
}

variable "secret_references" {
  type        = map(object({ secret_id = string, secret_version = optional(string, "latest") }))
  description = "Secret references keyed by environment variable"
  default     = {}
}
