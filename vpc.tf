resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false # Only create subnet in configured region
}

# Create subnets in different zones
resource "google_compute_subnetwork" "this" {
  name          = var.name
  ip_cidr_range = var.subnetwork_cidr
  region        = data.google_client_config.current.region
  network       = google_compute_network.this.name

  # Enable private Google access
  private_ip_google_access = true

  # Enable flow logs
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = var.name
  region  = data.google_client_config.current.region
  network = google_compute_network.this.id
}

# Cloud NAT configuration
resource "google_compute_router_nat" "nat" {
  name                               = var.name
  router                             = google_compute_router.router.name
  region                             = data.google_client_config.current.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall rules for internal communication
resource "google_compute_firewall" "internal" {
  name    = "${var.name}-internal"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnetwork_cidr]
}

# Private Service Connection
resource "google_compute_global_address" "this" {
  name          = var.name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "private_service_connection" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.this.name]
}

# Static External IP for Ingress
resource "google_compute_global_address" "ingress" {
  count = var.provision_static_ip ? 1 : 0
  name  = "${var.name}-ingress-ip"
}
