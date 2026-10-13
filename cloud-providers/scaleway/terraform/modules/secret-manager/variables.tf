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

variable "secret_names" {
  type        = set(string)
  description = "Non-sensitive logical names; must match secret_values keys"
}

variable "secret_values" {
  type        = map(string)
  description = "Secret values; stored in Terraform state"
  sensitive   = true
}
