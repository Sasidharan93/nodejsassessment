terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.app_name}-repo"
  format        = "DOCKER"
  description   = "Docker images for ${var.app_name}"
}

resource "google_cloud_run_v2_service" "app" {
  name     = "${var.app_name}-service"
  project  = var.project_id
  location = var.region

  template {
    service_account = var.cloud_run_sa_email

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY" # only route VPC-bound traffic through connector, public internet stays direct
    }

    containers {
      image = var.container_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      ports {
        container_port = 8080
      }

      env {
        name = "DB_HOST"
        value_source {
          secret_key_ref {
            secret  = var.secret_ids["db-host"]
            version = "latest"
          }
        }
      }
      env {
        name = "DB_NAME"
        value_source {
          secret_key_ref {
            secret  = var.secret_ids["db-name"]
            version = "latest"
          }
        }
      }
      env {
        name = "DB_USER"
        value_source {
          secret_key_ref {
            secret  = var.secret_ids["db-user"]
            version = "latest"
          }
        }
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.secret_ids["db-password"]
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 3
      }
    }

    annotations = {
      "run.googleapis.com/cloudsql-instances" = var.cloud_sql_connection_name
    }
  }

  # CI/CD will update the image; don't fight it on every terraform apply
  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }
}

# Allow unauthenticated access (public API) - change this if your assignment
# expects the API to be private/internal only
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
