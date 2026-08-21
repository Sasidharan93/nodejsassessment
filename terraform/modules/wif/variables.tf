variable "project_id" {
  type = string
}

variable "github_repo" {
  description = "GitHub repo in format owner/repo"
  type        = string
}

variable "deployer_sa_email" {
  type = string
}
