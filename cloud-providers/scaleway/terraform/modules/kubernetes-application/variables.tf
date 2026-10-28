variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "correspondence"
}

variable "image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 2525
}

variable "public_port" {
  type    = number
  default = 80
}

variable "health_path" {
  type    = string
  default = "/health"
}

variable "replicas" {
  type    = number
  default = 1
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "secret_environment_variables" {
  type      = map(string)
  default   = {}
  sensitive = true
}

variable "cpu_request" {
  type    = string
  default = "500m"
}

variable "cpu_limit" {
  type    = string
  default = "1100m"
}

variable "memory_request" {
  type    = string
  default = "1Gi"
}

variable "memory_limit" {
  type    = string
  default = "2Gi"
}

variable "create_registry_pull_secret" {
  type    = bool
  default = false
}

variable "registry_server" {
  type    = string
  default = ""
}

variable "registry_username" {
  type    = string
  default = ""
}

variable "registry_password" {
  type      = string
  default   = ""
  sensitive = true
}
