data "google_compute_subnetwork" "consumer_subnet" {
  project = var.project_id
  region  = var.region
  name    = var.consumer_subnet_name
}

# Regional PSC NEG that consumes Apigee's serviceAttachment
resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  provider              = google-beta
  name                  = var.neg_name
  region                = var.region
  network               = var.vpc_self_link
  subnetwork            = data.google_compute_subnetwork.consumer_subnet.self_link
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = var.apigee_service_attachment_uri
}

# (Optional) Cloud Armor policy
#resource "google_compute_security_policy" "api_policy" {
#  count = var.enable_cloud_armor ? 1 : 0
#  name  = var.cloud_armor_name
#
#  # Default allow (adjust to rules you want; you can flip to deny-by-default + allowlists)
#  rule {
#    priority = 2147483647
#    action   = "allow"
#    match { expr { expression = "true" } }
#    description = "Default allow (tighten with specific rules as needed)"
#  }
#}

# Backend service using the PSC NEG
resource "google_compute_backend_service" "apigee_backend" {
  name                  = var.backend_service_name
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30

  log_config { enable = true }

  dynamic "security_settings" {
    for_each = var.enable_cloud_armor ? [1] : []
    content {
      # placeholder; use security_policy on the backend service instead
    }
  }

  backend {
    group = google_compute_region_network_endpoint_group.apigee_psc_neg.id
  }

  # Attach Cloud Armor to the backend service if enabled
  # security_policy = var.enable_cloud_armor ? google_compute_security_policy.api_policy[0].self_link : null
}

# All traffic for this LB goes to Apigee (single-host LB)
resource "google_compute_url_map" "api_map" {
  name            = var.url_map_name
  default_service = google_compute_backend_service.apigee_backend.self_link

  host_rule {
    hosts        = [var.api_host]
    path_matcher = "all-to-apigee"
  }

  path_matcher {
    name            = "all-to-apigee"
    default_service = google_compute_backend_service.apigee_backend.self_link
  }
}

# Google-managed cert for the API host
resource "google_compute_managed_ssl_certificate" "api_cert" {
  name = var.cert_name
  managed {
    domains = [var.api_host]
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "api_https_proxy" {
  name             = var.https_proxy_name
  url_map          = google_compute_url_map.api_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api_cert.id]
}

# New global static IP for this API LB
resource "google_compute_global_address" "api_ip" {
  name = var.static_ip_name
}

# External Managed HTTPS forwarding rule (ports 443)
resource "google_compute_global_forwarding_rule" "api_fr" {
  name                  = var.fr_name
  ip_address            = google_compute_global_address.api_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.api_https_proxy.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
