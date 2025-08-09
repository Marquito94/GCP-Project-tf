############################################
# Project info
############################################
data "google_project" "current" {
  project_id = var.project_id
}

############################################
# Deployer Service Account (uploads only)
############################################
resource "google_service_account" "deployer" {
  account_id   = var.deployer_sa_id
  display_name = "Static Website Deployer (GitHub Actions)"
  # If you enable APIs in apis.tf, keep:
  depends_on   = [google_project_service.enable_iam]
}

############################################
# Private GCS bucket (static website origin)
############################################
resource "google_storage_bucket" "site" {
  name                        = var.bucket_name
  location                    = var.location
  uniform_bucket_level_access = true
  force_destroy               = true

  # Prevent any public grant
  public_access_prevention = "enforced"

  website {
    main_page_suffix = var.main_page
    not_found_page   = var.error_page
  }

  # Optional CORS for frontend XHR/fetch
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Cache-Control"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    action    { type = "Delete" }
    condition { age  = 365 }
  }

  depends_on = [google_project_service.enable_storage]
}

# CI can upload/manage objects (no bucket-setting changes)
resource "google_storage_bucket_iam_binding" "sa_object_admin" {
  bucket  = google_storage_bucket.site.name
  role    = "roles/storage.objectAdmin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

# LB’s Google-managed SA can read objects from the bucket
resource "google_storage_bucket_iam_binding" "lb_object_viewer" {
  bucket  = google_storage_bucket.site.name
  role    = "roles/storage.objectViewer"
  members = [
    "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
  ]
}

############################################
# Global Load Balancer (bucket backend)
############################################

# Origin: the private bucket (CDN optional)
resource "google_compute_backend_bucket" "frontend" {
  name        = "frontend-backend-bucket"
  bucket_name = google_storage_bucket.site.name
  enable_cdn  = true
  depends_on  = [google_project_service.enable_compute]
}

# Managed SSL cert for your domain (HTTPS frontend)
resource "google_compute_managed_ssl_certificate" "cert" {
  name = "frontend-ssl-cert"
  managed { domains = [var.domain] }
}

# One URL map used by BOTH HTTP and HTTPS (no redirect)
resource "google_compute_url_map" "main_map" {
  name            = "frontend-url-map"
  default_service = google_compute_backend_bucket.frontend.id
}

# HTTPS proxy (uses cert + URL map)
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "frontend-https-proxy"
  url_map          = google_compute_url_map.main_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# HTTP proxy (no redirect; uses same URL map)
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "frontend-http-proxy"
  url_map = google_compute_url_map.main_map.id
}

# One global static IP for both listeners
resource "google_compute_global_address" "ip" {
  name = "frontend-static-ip"
}

# Forwarding rules
resource "google_compute_global_forwarding_rule" "https_rule" {
  name                  = "frontend-https-fr"
  ip_address            = google_compute_global_address.ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.id
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_global_forwarding_rule" "http_rule" {
  name                  = "frontend-http-fr"
  ip_address            = google_compute_global_address.ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  load_balancing_scheme = "EXTERNAL"
}
