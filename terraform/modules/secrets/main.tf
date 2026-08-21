locals {
  secrets = {
    "db-host"     = var.db_host
    "db-name"     = var.db_name
    "db-user"     = var.db_user
    "db-password" = var.db_password
  }
}

resource "google_secret_manager_secret" "secret" {
  for_each  = local.secrets
  project   = var.project_id
  secret_id = "${var.app_name}-${each.key}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "secret_version" {
  for_each    = local.secrets
  secret      = google_secret_manager_secret.secret[each.key].id
  secret_data = each.value
}
