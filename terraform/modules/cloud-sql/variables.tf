variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "network_id" {
  description = "VPC network self-link/id for private IP config"
  type        = string
}

variable "private_vpc_connection" {
  description = "Ensures Cloud SQL waits for VPC peering to exist first"
  type        = string
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_user" {
  type    = string
  default = "appuser"
}

variable "tier" {
  description = "Cloud SQL machine tier - small for dev/assessment purposes"
  type        = string
  default     = "db-f1-micro"
}
