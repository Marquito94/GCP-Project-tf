########################################################
# PATCH: use locals for names + var.apigee_host
########################################################
locals {
  neg_name              = "apigee-api-psc-neg"
  backend_service_name  = "apigee-api-backend"
  url_map_name          = "apigee-api-urlmap"
  cert_name             = "cert-apigee-api"
  https_proxy_name      = "apigee-api-https-proxy"
  fr_https_name         = "apigee-api-https-fr"
  # fr_http_name          = "apigee-api-http-fr"      # only if you add HTTP redirect
  static_ip_name        = "apigee-api-ip"
}

data "google_compute_subnetwork" "consumer_subnet" {
  project = var.project_id
  region  = var.region
  name    = var.consumer_subnet_name
}

# Regional PSC NEG -> Apigee ingress (needs google-beta)
resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  provider              = google-beta
  name                  = local.neg_name
  region                = var.region
  network               = var.vpc_self_link
  subnetwork            = data.google_compute_subnetwork.consumer_subnet.self_link
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = var.apigee_service_attachment_uri
}

# Backend service using the PSC NEG (External Managed)
resource "google_compute_backend_service" "apigee_backend" {
  name                  = local.backend_service_name
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30

  log_config { enable = true }

  backend {
    group = google_compute_region_network_endpoint_group.apigee_psc_neg.id
  }

  # Optional: attach Cloud Armor if you toggle it on
  # security_policy = var.enable_cloud_armor ? google_compute_security_policy.api_policy[0].self_link : null
}

# Optional Cloud Armor policy (toggle with var.enable_cloud_armor)
# resource "google_compute_security_policy" "api_policy" {
# count = var.enable_cloud_armor ? 1 : 0
#  name  = var.cloud_armor_name
#
#  rule {
#    priority = 2147483647
#    action   = "allow"
#    match { expr { expression = "true" } }
#    description = "Default allow (tighten as needed)"
#  }
#}

# URL map: all traffic for this host -> Apigee backend
resource "google_compute_url_map" "api_map" {
  name            = local.url_map_name
  default_service = google_compute_backend_service.apigee_backend.self_link

  host_rule {
    hosts        = [var.apigee_host]  # <-- you already have this var
    path_matcher = "all-to-apigee"
  }

  path_matcher {
    name            = "all-to-apigee"
    default_service = google_compute_backend_service.apigee_backend.self_link
  }
}

# Managed cert for the API host
resource "google_compute_managed_ssl_certificate" "api_cert" {
  name = local.cert_name
  managed { domains = [var.apigee_host] }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "api_https_proxy" {
  name             = local.https_proxy_name
  url_map          = google_compute_url_map.api_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api_cert.id]
}

# New global static IP (dedicated to this API LB)
resource "google_compute_global_address" "api_ip" {
  name = local.static_ip_name
}

# HTTPS forwarding rule (External Managed)
resource "google_compute_global_forwarding_rule" "api_https_fr" {
  name                  = local.fr_https_name
  ip_address            = google_compute_global_address.api_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.api_https_proxy.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# OPTIONAL: HTTP -> HTTPS redirect on same IP
# Uncomment this section if you want port 80 to redirect to HTTPS.
# resource "google_compute_url_map" "api_http_redirect_map" {
#   name = "http-to-https-apigee-map"
#   default_url_redirect {
#     https_redirect = true
#     strip_query    = false
#   }
# }
#
# resource "google_compute_target_http_proxy" "api_http_proxy" {
#   name    = "apigee-api-http-proxy"
#   url_map = google_compute_url_map.api_http_redirect_map.id
# }
#
# resource "google_compute_global_forwarding_rule" "api_http_fr" {
#   name                  = local.fr_http_name
#   ip_address            = google_compute_global_address.api_ip.address
#   port_range            = "80"
#   target                = google_compute_target_http_proxy.api_http_proxy.id
#   load_balancing_scheme = "EXTERNAL_MANAGED"
# }

output "api_ip" {
  value = google_compute_global_address.api_ip.address
}
