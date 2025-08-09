locals {
  repo_full = "${var.github_owner}/${var.github_repo}"
}

resource "google_service_account" "gh_deployer" {
  account_id   = "gh-deployer"
  display_name = "GitHub Actions Deployer"
}

resource "google_iam_workload_identity_pool" "gh_pool" {
  provider                  = google-beta
  workload_identity_pool_id = var.wip_id
  display_name              = "GitHub OIDC Pool"
}

resource "google_iam_workload_identity_pool_provider" "gh_provider" {
  provider                           = google-beta
  workload_identity_pool_id          = google_iam_workload_identity_pool.gh_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wip_provider_id
  display_name                       = "GitHub OIDC Provider"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_binding" "sa_wiu" {
  service_account_id = google_service_account.gh_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_pool.name}/attribute.repository/${local.repo_full}"
  ]
}

resource "google_storage_bucket" "site" {
  for_each = var.buckets

  name     = each.key
  location = var.location

  uniform_bucket_level_access = true
  force_destroy               = true

  website {
    main_page_suffix = each.value.main_page
    not_found_page   = each.value.error_page
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

resource "google_storage_bucket_iam_binding" "sa_object_admin" {
  for_each = var.buckets

  bucket = google_storage_bucket.site[each.key].name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.gh_deployer.email}"
  ]
}

resource "google_storage_bucket_iam_binding" "public_read" {
  for_each = var.make_buckets_public ? var.buckets : {}

  bucket = google_storage_bucket.site[each.key].name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers"
  ]
}
