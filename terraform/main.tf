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

provider "google" {
  project = var.project_id
  region  = var.region
}

module "network" {
  source       = "./modules/network"
  project_id   = var.project_id
  region       = var.region
  network_name = "${var.app_name}-vpc"
}

module "cloud_sql" {
  source                 = "./modules/cloud-sql"
  project_id             = var.project_id
  region                 = var.region
  app_name               = var.app_name
  network_id             = module.network.network_id
  private_vpc_connection = module.network.private_vpc_connection
}

module "secrets" {
  source      = "./modules/secrets"
  project_id  = var.project_id
  app_name    = var.app_name
  db_host     = module.cloud_sql.private_ip_address
  db_name     = module.cloud_sql.db_name
  db_user     = module.cloud_sql.db_user
  db_password = module.cloud_sql.db_password
}


module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  app_name   = var.app_name
}


module "cloud_run" {
  source                    = "./modules/cloud-run"
  project_id                = var.project_id
  region                    = var.region
  app_name                  = var.app_name
  vpc_connector_id          = module.network.vpc_connector_id
  cloud_run_sa_email        = module.iam.cloud_run_sa_email
  cloud_sql_connection_name = module.cloud_sql.instance_connection_name
  secret_ids                = module.secrets.secret_ids
}



module "monitoring" {
  source                  = "./modules/monitoring"
  project_id              = var.project_id
  app_name                = var.app_name
  cloud_run_service_name  = "${var.app_name}-service"
  alert_email             = var.alert_email
  google_chat_webhook_url = var.google_chat_webhook_url
}
