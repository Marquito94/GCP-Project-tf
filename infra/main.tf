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

  public_access_prevention = "enforced"

  website {
    main_page_suffix = var.main_page
    not_found_page   = var.error_page
  }

  # Optional CORS for frontend fetches
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

# CI can upload/manage objects (objects only)
resource "google_storage_bucket_iam_binding" "sa_object_admin" {
  bucket  = google_storage_bucket.site.name
  role    = "roles/storage.objectAdmin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

# LB’s Google-managed SA can read objects
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

# URL map for serving the site (used by HTTPS; HTTP redirects to HTTPS)
# Includes rewrites so clean paths work.
resource "google_compute_url_map" "https_map" {
  provider        = google-beta
  name            = "frontend-url-map"
  default_service = google_compute_backend_bucket.frontend.id

  # / -> /index.html
  route_rules {
    priority = 1
    match_rules { full_path_match = "/" }
    service = google_compute_backend_bucket.frontend.id
    route_action {
      url_rewrite { path_template_rewrite = "/index.html" }
    }
  }

  # /solutions -> /solutions/index.html
  route_rules {
    priority = 2
    match_rules { full_path_match = "/solutions" }
    service = google_compute_backend_bucket.frontend.id
    route_action {
      url_rewrite { path_template_rewrite = "/solutions/index.html" }
    }
  }

  # /delivery -> /delivery/index.html
  route_rules {
    priority = 3
    match_rules { full_path_match = "/delivery" }
    service = google_compute_backend_bucket.frontend.id
    route_action {
      url_rewrite { path_template_rewrite = "/delivery/index.html" }
    }
  }

  # /status -> /status/index.html
  route_rules {
    priority = 4
    match_rules { full_path_match = "/status" }
    service = google_compute_backend_bucket.frontend.id
    route_action {
      url_rewrite { path_template_rewrite = "/status/index.html" }
    }
  }
}

# HTTPS proxy with the cert (serves content)
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "frontend-https-proxy"
  url_map          = google_compute_url_map.https_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# HTTP → HTTPS redirect map
resource "google_compute_url_map" "http_redirect_map" {
  name = "http-to-https-redirect-map"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

# HTTP proxy that uses the redirect map
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "frontend-http-redirect-proxy"
  url_map = google_compute_url_map.http_redirect_map.id
}

# One global static IP (shared by 80/443)
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
