variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "vpc_connector_id" {
  type = string
}

variable "cloud_run_sa_email" {
  type = string
}

variable "cloud_sql_connection_name" {
  type = string
}

variable "secret_ids" {
  description = "Map of secret keys to their Secret Manager secret_ids"
  type        = map(string)
}

variable "container_image" {
  description = "Full image path - passed in later by CI/CD, defaults to a placeholder for first apply"
  type        = string
  default     = "gcr.io/cloudrun/hello" # placeholder until first real image is pushed
}
