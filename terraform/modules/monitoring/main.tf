# --- Notification Channels ---

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "${var.app_name} Email Alerts"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_notification_channel" "chat" {
  project      = var.project_id
  display_name = "${var.app_name} Google Chat Warnings"
  type         = "webhook_tokenauth"
  labels = {
    url = var.google_chat_webhook_url
  }
  sensitive_labels {
    auth_token = "" # webhook URL itself carries the auth; kept blank intentionally
  }
}

# --- Log-based metric: counts 5xx errors from the app ---

resource "google_logging_metric" "error_count" {
  project = var.project_id
  name    = "${var.app_name}-5xx-errors"
  filter  = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloud_run_service_name}\" AND httpRequest.status>=500"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# --- CPU Alert: >70% -> Chat warning ---

resource "google_monitoring_alert_policy" "cpu_warning" {
  project      = var.project_id
  display_name = "${var.app_name} CPU > 70% (Warning)"
  combiner     = "OR"

  conditions {
    display_name = "CPU utilization above 70%"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/container/cpu/utilizations\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.70
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.chat.id]

  alert_strategy {
    auto_close = "1800s"
  }
}

# --- CPU Alert: >80% sustained -> Email critical ---

resource "google_monitoring_alert_policy" "cpu_critical" {
  project      = var.project_id
  display_name = "${var.app_name} CPU > 80% (Critical)"
  combiner     = "OR"

  conditions {
    display_name = "CPU utilization above 80% for consecutive datapoints"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/container/cpu/utilizations\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      duration        = "180s" # sustained across multiple datapoints, not a single spike
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"
  }
}

# --- Memory Alert: >70% -> Chat warning ---

resource "google_monitoring_alert_policy" "memory_warning" {
  project      = var.project_id
  display_name = "${var.app_name} Memory > 70% (Warning)"
  combiner     = "OR"

  conditions {
    display_name = "Memory utilization above 70%"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/container/memory/utilizations\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.70
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.chat.id]

  alert_strategy {
    auto_close = "1800s"
  }
}

# --- Memory Alert: >80% sustained -> Email critical ---

resource "google_monitoring_alert_policy" "memory_critical" {
  project      = var.project_id
  display_name = "${var.app_name} Memory > 80% (Critical)"
  combiner     = "OR"

  conditions {
    display_name = "Memory utilization above 80% for consecutive datapoints"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/container/memory/utilizations\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      duration        = "180s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"
  }
}
