resource "google_dns_managed_zone" "private_zone" {
  project     = var.project_id
  name        = var.private_zone_name
  dns_name    = var.private_dns_name
  description = "Private zone for internal-only resolution"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.vpc_self_link
    }
  }
}

output "private_zone_dns_name" {
  value = google_dns_managed_zone.private_zone.dns_name
}

resource "google_dns_record_set" "backend_a" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.private_zone.name

  name = "backend.${google_dns_managed_zone.private_zone.dns_name}"  # e.g. backend.internal.api....com.

  type = "A"
  ttl  = 300
  rrdatas = [
    "10.0.12.34",  # <-- replace with your ILB_IP
  ]
}
