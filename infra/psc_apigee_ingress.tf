data "google_compute_subnetwork" "consumer_subnet" {
  project = var.project_id
  region  = var.region
  name    = var.consumer_subnet_name
}

# Use google-beta here if your google provider is older
resource "google_compute_region_network_endpoint_group" "apigee_ingress_psc_neg" {
  provider              = google-beta
  name                  = "apigee-ingress-psc-neg"
  region                = var.region
  network               = var.vpc_self_link
  subnetwork            = data.google_compute_subnetwork.consumer_subnet.self_link
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"

  psc_target_service    = var.apigee_service_attachment_uri
}

# Backend service that uses the NEG above
resource "google_compute_backend_service" "apigee_ingress_bs" {
  name                  = "apigee-ingress-psc-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30

  log_config { enable = true }

  backend {
    group = google_compute_region_network_endpoint_group.apigee_ingress_psc_neg.id
  }
}

output "apigee_ingress_backend_self_link" {
  value = google_compute_backend_service.apigee_ingress_bs.self_link
}
