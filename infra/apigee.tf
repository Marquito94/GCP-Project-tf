########################
# Network + peering setup
########################
data "google_compute_network" "vpc" {
  name = var.vpc_name
}

# Reserve INTERNAL range for Service Networking peering (Apigee requirement)
resource "google_compute_global_address" "service_range" {
  name          = "apigee-servicenetworking-range"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 22
  network       = data.google_compute_network.vpc.self_link

  depends_on = [
    google_project_service.compute,
    google_project_service.servicenetworking
  ]
}

# Establish VPC peering with Service Networking
resource "google_service_networking_connection" "vpc_connection" {
  network                 = data.google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.service_range.name]

  depends_on = [
    google_project_service.servicenetworking,
    google_compute_global_address.service_range
  ]
}

########################
# Apigee Org / Instance
########################
resource "google_apigee_organization" "org" {
  provider         = google-beta
  project_id       = var.project_id
  analytics_region = var.region
  display_name     = var.project_id

  # Connect Apigee runtime to your VPC
  authorized_network = data.google_compute_network.vpc.self_link

  depends_on = [
    google_project_service.apigee,
    google_service_networking_connection.vpc_connection
  ]
}

# Apigee X instance (runtime)
resource "google_apigee_instance" "instance" {
  provider  = google-beta
  org_id    = google_apigee_organization.org.id
  name      = "apigee-x-${var.region}"
  location  = var.region
  ip_range  = var.apigee_cidr  # /22 in your VPC

  depends_on = [google_apigee_organization.org]
}

# Environment
resource "google_apigee_environment" "env" {
  provider = google-beta
  org_id   = google_apigee_organization.org.id
  name     = var.apigee_env_name

  depends_on = [google_apigee_instance.instance]
}

# Attach env to instance
resource "google_apigee_instance_attachment" "instance_env" {
  provider   = google-beta
  instance_id = google_apigee_instance.instance.id
  environment = google_apigee_environment.env.name

  depends_on = [google_apigee_environment.env]
}

# Env Group with your public host (what the frontend will call)
resource "google_apigee_envgroup" "eg" {
  provider  = google-beta
  org_id    = google_apigee_organization.org.id
  name      = var.apigee_envgroup_name
  hostnames = [var.apigee_host]
}

# Map env → env group
resource "google_apigee_envgroup_attachment" "eg_attach" {
  provider    = google-beta
  envgroup_id = google_apigee_envgroup.eg.id
  environment = google_apigee_environment.env.name
}
