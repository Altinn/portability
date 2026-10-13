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

variable "cidr" {
  type        = string
  description = "Private IPv4 subnet"
  default     = "10.20.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}
