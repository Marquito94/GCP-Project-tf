# --- VPC + Subnet lookups ---
data "google_compute_network" "vpc" {
  project = var.project_id
  name    = var.vpc_name
}

data "google_compute_subnetwork" "ilb_subnet" {
  project = var.project_id
  region  = var.region
  name    = var.ilb_subnet_name  # e.g., "default"
}

# --- Private zone ---
resource "google_dns_managed_zone" "private_zone" {
  project     = var.project_id
  name        = var.private_zone_name
  dns_name    = var.private_dns_name  # must end with a dot
  description = "Private zone for internal-only resolution"
  visibility  = "private"

  private_visibility_config {
    networks { network_url = var.vpc_self_link }
  }
}

output "private_zone_dns_name" {
  value = google_dns_managed_zone.private_zone.dns_name
}

# --- Reserve internal ILB IP ---
resource "google_compute_address" "ilb_ip" {
  name         = var.ilb_ip_name
  region       = var.region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = data.google_compute_subnetwork.ilb_subnet.self_link
}

# --- Proxy-only subnet for Internal HTTPS LB ---
resource "google_compute_subnetwork" "ilb_proxy_only" {
  project       = var.project_id
  name          = "ilb-proxy-${var.region}"
  region        = var.region
  network       = data.google_compute_network.vpc.self_link
  ip_cidr_range = var.proxy_only_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# --- A record -> reserved ILB IP ---
resource "google_dns_record_set" "backend_a" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.private_zone.name
  name         = "${google_dns_managed_zone.private_zone.dns_name}" # e.g., backend.internal.apipueba-web-dev.com.
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.ilb_ip.address]

  depends_on = [google_dns_managed_zone.private_zone]
}
