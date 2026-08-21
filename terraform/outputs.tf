output "vpc_connector_id" {
  value = module.network.vpc_connector_id
}

output "cloud_sql_connection_name" {
  value = module.cloud_sql.instance_connection_name
}

output "cloud_sql_private_ip" {
  value = module.cloud_sql.private_ip_address
}

output "cloud_run_sa_email" {
  value = module.iam.cloud_run_sa_email
}

output "deployer_sa_email" {
  value = module.iam.deployer_sa_email
}

output "cloud_run_url" {
  value = module.cloud_run.service_url
}

output "artifact_registry_url" {
  value = module.cloud_run.repository_url
}

output "workload_identity_provider" {
  value = module.wif.workload_identity_provider
}
