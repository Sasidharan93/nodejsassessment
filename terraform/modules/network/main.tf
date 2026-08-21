# Custom VPC - no auto-created subnets, we control everything explicitly
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet for Cloud Run's VPC connector and any future resources
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  # Enables Private Google Access - lets resources without public IPs reach Google APIs
  private_ip_google_access = true
}

# Reserved IP range for private services connection (needed for Cloud SQL private IP)
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.network_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# Establishes the private connection (VPC peering) that Cloud SQL uses
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# VPC Connector - lets Cloud Run (serverless) reach into this VPC
resource "google_vpc_access_connector" "connector" {
  name          = "nodejs-vpc-conn"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"
  project       = var.project_id

  min_instances = 2
  max_instances = 3
}

# Firewall: allow internal traffic within the VPC only (Cloud Run <-> Cloud SQL)
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["5432"] # PostgreSQL port
  }

  source_ranges = ["10.0.0.0/24", "10.8.0.0/28"]
}

# Deny all other ingress by default (explicit, defense in depth)
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "${var.network_name}-deny-all-ingress"
  network   = google_compute_network.vpc.name
  project   = var.project_id
  priority  = 65534
  direction = "INGRESS"

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}
