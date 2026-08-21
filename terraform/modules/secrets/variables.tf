variable "project_id" {
  type = string
}

variable "app_name" {
  type = string
}

variable "db_host" {
  description = "Cloud SQL private IP"
  type        = string
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
