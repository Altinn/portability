variable "project_id" {
  type        = string
  description = "Digdir project UUID"
}

variable "region" {
  type        = string
  description = "State bucket region"
  default     = "fr-par"
}

variable "zone" {
  type        = string
  description = "Provider zone"
  default     = "fr-par-1"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique state bucket name"
}
