variable "project_id" {
  type = string
}

variable "app_name" {
  type = string
}

variable "cloud_run_service_name" {
  type = string
}

variable "alert_email" {
  description = "Email address to receive critical (>80%) alerts"
  type        = string
}

variable "google_chat_webhook_url" {
  description = "Google Chat webhook URL for warning (>70%) alerts"
  type        = string
  sensitive   = true
}
