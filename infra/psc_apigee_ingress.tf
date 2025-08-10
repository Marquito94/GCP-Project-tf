# PSC NEG so your LB can consume Apigee's ingress serviceAttachment
resource "google_compute_network_endpoint_group" "apigee_ingress_psc_neg" {
  name                  = "apigee-ingress-psc-neg"
  region                = var.region
  network               = var.vpc_self_link
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"

  # Preferred: pull directly from your Apigee instance
  psc_target_service = google_apigee_instance.instance.service_attachment
  # If your provider version lacks this field, use a var instead:
  # psc_target_service = var.apigee_service_attachment_uri
}

# Backend service that uses the NEG above
resource "google_compute_backend_service" "apigee_ingress_bs" {
  name                  = "apigee-ingress-psc-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30

  log_config { enable = true }

  backend {
    group = google_compute_network_endpoint_group.apigee_ingress_psc_neg.id
  }
}

output "apigee_ingress_backend_self_link" {
  value = google_compute_backend_service.apigee_ingress_bs.self_link
}
