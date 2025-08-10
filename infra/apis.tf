resource "google_project_service" "enable_cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "enable_iam" {
  project = var.project_id
  service = "iam.googleapis.com"
}

resource "google_project_service" "enable_compute" {
  project = var.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "enable_storage" {
  project = var.project_id
  service = "storage.googleapis.com"
}

resource "google_project_service" "servicenetworking" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "apigee" {
  project = var.project_id
  service = "apigee.googleapis.com"
}
