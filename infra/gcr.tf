resource "google_project_service" "artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

# Docker repository
resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.ar_repo_name
  description   = "Docker images for API backend"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}

# Default compute service account (used by GKE nodes)
data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# Let nodes pull images from Artifact Registry
resource "google_project_iam_member" "nodes_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}
