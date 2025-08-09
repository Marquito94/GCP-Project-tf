data "google_project" "current" {
  project_id = var.project_id
}

# --- Service Account for CI deploys (uploads only) ---
resource "google_service_account" "deployer" {
  account_id   = var.deployer_sa_id
  display_name = "Static Website Deployer (GitHub Actions)"
  depends_on   = [google_project_service.enable_iam]
}

# JSON key to use in GitHub Actions secret GCP_SA_KEY
resource "google_service_account_key" "deployer_key" {
  service_account_id = google_service_account.deployer.name
}

############################################
# Private GCS bucket (static website origin)
############################################

resource "google_storage_bucket" "site" {
  name                        = var.bucket_name
  location                    = var.location
  uniform_bucket_level_access = true
  force_destroy               = true

  # Hard-block any future public grants
  public_access_prevention = "enforced"

  website {
    main_page_suffix = var.main_page
    not_found_page   = var.error_page
  }

  # (Optional) basic CORS for browser fetches if you call external APIs
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

# CI can upload/manage objects (objects only; no bucket setting changes)
resource "google_storage_bucket_iam_binding" "sa_object_admin" {
  bucket = google_storage_bucket.site.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.deployer.email}"
  ]
}

# Allow only the Load Balancer's Google-managed SA to read objects
resource "google_storage_bucket_iam_binding" "lb_object_viewer" {
  bucket = google_storage_bucket.site.name
  role   = "roles/storage.objectViewer"
  members = [
    "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
  ]
}

############################################
# Global HTTPS Load Balancer (bucket backend)
############################################

# Backend bucket (origin is the private GCS bucket)
resource "google_compute_backend_bucket" "frontend" {
  name        = "frontend-backend-bucket"
  bucket_name = google_storage_bucket.site.name
  enable_cdn  = true
  depends_on  = [google_project_service.enable_compute]
}

# Managed SSL certificate for your domain (e.g., app.example.com)
resource "google_compute_managed_ssl_certificate" "cert" {
  name = "frontend-ssl-cert"
  managed { domains = [var.domain] }
}

# URL map for HTTPS traffic → backend bucket
resource "google_compute_url_map" "https_map" {
  name            = "frontend-url-map"
  default_service = google_compute_backend_bucket.frontend.id
}

# HTTPS proxy with the cert
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "frontend-https-proxy"
  url_map          = google_compute_url_map.https_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# HTTP → HTTPS redirect
resource "google_compute_url_map" "http_redirect_map" {
  name = "http-to-https-redirect-map"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "frontend-http-redirect-proxy"
  url_map = google_compute_url_map.http_redirect_map.id
}

# One global static IP for the LB
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

############################################
# Outputs (handy in a single file)
############################################

output "service_account_email" {
  value       = google_service_account.deployer.email
  description = "Deployer Service Account email"
}

output "bucket_name" {
  value       = google_storage_bucket.site.name
  description = "Private website bucket name"
}

output "lb_ip" {
  value       = google_compute_global_address.ip.address
  description = "Create an A record for var.domain pointing to this IP"
}

output "https_url" {
  value       = "https://${var.domain}"
  description = "Site URL via HTTPS Load Balancer (after DNS + cert ACTIVE)"
}
