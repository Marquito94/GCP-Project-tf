#############################################
# PSC (producer) for your GKE Internal LB
#############################################

# PSC NAT subnet for Service Attachment (producer side)
resource "google_compute_subnetwork" "psc_nat_subnet" {
  name          = "psc-nat-${var.region}"
  region        = var.region
  network       = data.google_compute_network.vpc.self_link
  ip_cidr_range = var.psc_nat_subnet_cidr
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

resource "google_apigee_endpoint_attachment" "ea" {
  provider            = google-beta
  endpoint_attachment_id = "ea-gke-ilb"
  location            = var.region
  org_id              = google_apigee_organization.org.id

  service_attachment = "projects/${var.project_id}/regions/${var.region}/serviceAttachments/${google_compute_service_attachment.gke_ilb_attachment.name}"
  # Note: provider expects short name path: projects/<proj>/regions/<region>/serviceAttachments/<name>
  # If needed, replace above with: google_compute_service_attachment.gke_ilb_attachment.id

  depends_on = [
    google_apigee_envgroup.eg,
    google_compute_service_attachment.gke_ilb_attachment,
    google_apigee_instance_attachment.instance_env
  ]
}

output "service_attachment_uri" {
  value = google_compute_service_attachment.gke_ilb_attachment.self_link
}

#############################################
# Apigee Endpoint Attachment (consumer)
#############################################
resource "google_compute_service_attachment" "gke_ilb_attachment" {
  name        = "gke-ilb-psc-${var.region}"
  project     = var.project_id
  region      = var.region

  # Your INTERNAL_MANAGED ILB Forwarding Rule selfLink from GKE Ingress
  target_service        = var.producer_forwarding_rule

  # Unless you specifically need PROXY protocol, leave false
  enable_proxy_protocol = false

  # 👇 Auto-approve consumers (Apigee)
  connection_preference = "ACCEPT_AUTOMATIC"

  nat_subnets = [google_compute_subnetwork.psc_nat_subnet.self_link]

  # IMPORTANT: Remove any consumer_accept_lists {} blocks if you had them

  depends_on = [google_compute_subnetwork.psc_nat_subnet]
}

resource "time_sleep" "wait_for_ea_host" {
  depends_on      = [google_apigee_endpoint_attachment.ea]
  create_duration = "60s"
}

# TargetServer in Apigee that points to the PSC hostname
resource "google_apigee_target_server" "ts_backend_psc" {
  provider   = google-beta
  env_id     = google_apigee_environment.env.id
  name       = "ts-gke-ilb"
  host       = google_apigee_endpoint_attachment.ea.host
  port       = 80
  protocol   = "HTTP"
  is_enabled = true

  depends_on = [
    google_apigee_endpoint_attachment.ea,
    time_sleep.wait_for_ea_host
  ]
}

output "apigee_psc_hostname" {
  description = "Hostname Apigee uses over PSC to reach your ILB"
  value       = google_apigee_endpoint_attachment.ea.host
}
