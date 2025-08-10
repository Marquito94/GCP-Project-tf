########################
# Network + peering setup
########################
# Reserve INTERNAL range for Service Networking peering (Apigee requirement)
resource "google_compute_global_address" "service_range" {
  name          = "apigee-servicenetworking-range"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 22
  network       = var.vpc_self_link

  depends_on = [
    google_project_service.enable_compute,
    google_project_service.servicenetworking
  ]
}

resource "google_compute_global_address" "service_range2" {
  name          = "apigee-servicenetworking-range2"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 19
  network       = var.vpc_self_link

  depends_on = [
    google_project_service.enable_compute,
    google_project_service.servicenetworking
  ]
}

# Establish VPC peering with Service Networking
resource "google_service_networking_connection" "vpc_connection" {
  network                 = data.google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.service_range2.name
  ]

  depends_on = [
    google_project_service.servicenetworking,
    google_compute_global_address.service_range,
    google_compute_global_address.service_range2
  ]
}

########################
# Apigee Org / Instance
########################
resource "google_apigee_organization" "org" {
  provider          = google-beta
  project_id        = var.project_id
  display_name      = var.project_id
  analytics_region  = var.region

  # MUST be short form (not selfLink)
  authorized_network = "projects/${var.project_id}/global/networks/${var.vpc_name}"

  # Properties must be declared as repeated property {} blocks
  properties {
    property {
      name  = "features.hybrid.enabled"
      value = "true"
    }
    property {
      name  = "features.mart.connect.enabled"
      value = "true"
    }
  }

  depends_on = [google_service_networking_connection.vpc_connection]
}

output "apigee_org_id" {
  value = google_apigee_organization.org.id
}

resource "google_apigee_instance" "instance" {
  provider = google-beta
  org_id   = google_apigee_organization.org.id
  name     = "apigee-x-${var.region}"
  location = var.region

  ip_range = var.apigee_cidr
}

resource "google_apigee_environment" "env" {
  provider = google-beta
  org_id   = google_apigee_organization.org.id
  name     = var.apigee_env_name
}

resource "google_apigee_instance_attachment" "instance_env" {
  provider    = google-beta
  instance_id = google_apigee_instance.instance.id
  environment = google_apigee_environment.env.name
}

resource "google_apigee_envgroup" "eg" {
  provider  = google-beta
  org_id    = google_apigee_organization.org.id
  name      = var.apigee_envgroup_name
  hostnames = [var.apigee_host]  # e.g. "api.pueba-web-dev.com"
}

resource "google_apigee_envgroup_attachment" "eg_attach" {
  provider    = google-beta
  envgroup_id = google_apigee_envgroup.eg.id
  environment = google_apigee_environment.env.name
}
