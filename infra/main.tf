/* Service Account for deploys */
resource "google_service_account" "deployer" {
  account_id   = var.deployer_sa_id
  display_name = "Static Website Deployer (GitHub Actions)"
}

/* JSON key for CI (store it as a GitHub secret; do NOT commit) */
resource "google_service_account_key" "deployer_key" {
  service_account_id = google_service_account.deployer.name
}

/* Single GCS Bucket for static website */
resource "google_storage_bucket" "site" {
  name     = var.bucket_name
  location = var.location

  uniform_bucket_level_access = true
  force_destroy               = true  # demo-friendly; disable in prod

  website {
    main_page_suffix = var.main_page
    not_found_page   = var.error_page
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Cache-Control"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }
  }
}

/* SA can deploy (objectAdmin) */
resource "google_storage_bucket_iam_binding" "sa_object_admin" {
  bucket = google_storage_bucket.site.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.deployer.email}"
  ]
}

/* Optional public read for quick website access */
resource "google_storage_bucket_iam_binding" "public_read" {
  count  = var.make_bucket_public ? 1 : 0
  bucket = google_storage_bucket.site.name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers"
  ]
}
