#############################################
# Data sources: VPC + Subnet for PSC NEG
#############################################
data "google_compute_network" "lb_vpc" {
  self_link = var.vpc_self_link
}

data "google_compute_subnetwork" "lb_subnet" {
  name    = var.consumer_subnet_name  # use your existing var (default "default")
  region  = var.region
  project = var.project_id
}

#############################################
# PSC NEG that targets Apigee serviceAttachment
#############################################
resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  name                  = "apigee-psc-neg-${var.region}"
  region                = var.region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"

  network    = data.google_compute_network.lb_vpc.self_link
  subnetwork = data.google_compute_subnetwork.lb_subnet.self_link

  # Pulls directly from your Apigee instance resource
  psc_target_service = google_apigee_instance.instance.service_attachment
}

#############################################
# Backend service (External Managed HTTPS) + NEG
#############################################
resource "google_compute_backend_service" "apigee_psc_backend" {
  name                  = "apigee-psc-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.apigee_psc_neg.self_link
  }
}

#############################################
# URL map (host-based) -> Apigee backend
#############################################
resource "google_compute_url_map" "api_url_map" {
  name = "api-url-map"

  host_rule {
    hosts        = [var.apigee_host]     # e.g. "api.pueba-web-dev.com"
    path_matcher = "api"
  }

  path_matcher {
    name            = "api"
    default_service = google_compute_backend_service.apigee_psc_backend.self_link
  }
}

#############################################
# Managed cert for api host
#############################################
resource "google_compute_managed_ssl_certificate" "api_cert" {
  name = "api-cert"
  managed {
    domains = [var.apigee_host]
  }
}

#############################################
# HTTPS proxy + global IP + forwarding rule (443)
#############################################
resource "google_compute_target_https_proxy" "api_https_proxy" {
  name             = "api-https-proxy"
  url_map          = google_compute_url_map.api_url_map.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.api_cert.self_link]
}

resource "google_compute_global_address" "api_ip" {
  name = "api-ip"
}

resource "google_compute_global_forwarding_rule" "api_fr_443" {
  name                  = "api-fr-443"
  ip_address            = google_compute_global_address.api_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.api_https_proxy.self_link
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

#############################################
# Outputs
#############################################
output "api_lb_ip" {
  description = "Public IP for api.* (point DNS A record here)"
  value       = google_compute_global_address.api_ip.address
}
