# Dedicated service account for Cloud Run - no default compute SA usage
resource "google_service_account" "cloud_run_sa" {
  project      = var.project_id
  account_id   = "${var.app_name}-run-sa"
  display_name = "Cloud Run runtime SA for ${var.app_name}"
}

# --- Minimal roles, granted individually (no Editor/Owner) ---

# Lets Cloud Run pull images from Artifact Registry
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Lets the app read secrets at runtime
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Lets Cloud Run connect to Cloud SQL via the connector/socket
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Lets the app write structured logs
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Lets the app write custom metrics (used later for monitoring/alerts)
resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# --- Separate deployer service account, for GitHub Actions CI/CD ---
resource "google_service_account" "deployer_sa" {
  project      = var.project_id
  account_id   = "${var.app_name}-deployer"
  display_name = "CI/CD deployer SA for ${var.app_name}"
}

resource "google_project_iam_member" "deployer_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.deployer_sa.email}"
}

resource "google_project_iam_member" "deployer_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.deployer_sa.email}"
}

# Deployer needs to act as the runtime SA to deploy Cloud Run with it attached
resource "google_service_account_iam_member" "deployer_can_act_as_runtime_sa" {
  service_account_id = google_service_account.cloud_run_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer_sa.email}"
}
