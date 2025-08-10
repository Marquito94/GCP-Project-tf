# Private suffix (must end with a dot)
# Example: "internal.apipueba-web-dev.com."
variable "private_dns_name" {
  type        = string
  description = "Private zone DNS name (with trailing dot)"
  default     = "internal.apipueba-web-dev.com."
}

variable "private_zone_name" {
  type        = string
  description = "Terraform name for the private zone"
  default     = "private-internal-zone"
}

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
