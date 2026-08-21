terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Generates a strong random password - never hardcoded, never in git
resource "random_password" "db_password" {
  length  = 20
  special = true
  # Avoid characters that cause issues in connection strings/shells
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_database_instance" "postgres" {
  name             = "${var.app_name}-pg"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_15"

  # Prevents accidental deletion via terraform destroy - remove only when intentionally tearing down
  deletion_protection = false # set true for real production use

  settings {
    tier = var.tier

    ip_configuration {
      ipv4_enabled                                  = false # NO public IP - private only
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }

    availability_type = "ZONAL" # use "REGIONAL" for production HA
  }

  depends_on = [var.private_vpc_connection]
}

resource "google_sql_database" "app_database" {
  name     = var.db_name
  project  = var.project_id
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  project  = var.project_id
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}
