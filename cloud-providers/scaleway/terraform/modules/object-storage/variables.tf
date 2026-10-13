variable "name" {
  type        = string
  description = "Globally unique lowercase bucket name"
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
  type        = map(string)
  description = "Bucket tags"
  default     = {}
}

variable "force_destroy" {
  type        = bool
  description = "Delete objects during destroy; irreversible"
  default     = false
}

variable "versioning_enabled" {
  type        = bool
  description = "Enable object versioning"
  default     = true
}
