variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "private_network_id" {
  type = string
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "kubernetes_version" {
  type    = string
  default = "1.37.1"
}

variable "node_type" {
  type    = string
  default = "DEV1-M"
}

variable "pool_size" {
  type    = number
  default = 1
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "autoscaling" {
  type    = bool
  default = false
}

variable "delete_additional_resources" {
  type    = bool
  default = true
}
