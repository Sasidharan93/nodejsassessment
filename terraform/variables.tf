variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

variable "app_name" {
  description = "Application name prefix for resources"
  type        = string
  default     = "nodejs-devsecops"
}

variable "alert_email" {
  description = "Email to receive critical alerts"
  type        = string
}

variable "google_chat_webhook_url" {
  description = "Google Chat webhook URL for warning alerts"
  type        = string
  sensitive   = true
}
