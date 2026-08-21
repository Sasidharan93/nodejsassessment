output "email_channel_id" {
  value = google_monitoring_notification_channel.email.id
}

output "chat_channel_id" {
  value = google_monitoring_notification_channel.chat.id
}
