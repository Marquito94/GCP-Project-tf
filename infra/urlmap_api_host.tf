# 1) Import (do this in CLI before apply):
# terraform import google_compute_url_map.existing <EXISTING_URL_MAP_NAME>

resource "google_compute_url_map" "existing" {
  name    = var.existing_url_map
  project = var.project_id

  #############################################
  # IMPORTANT:
  # After the import, run:
  #   terraform state show google_compute_url_map.existing
  # Copy your current fields here (default_service OR default_url_redirect /
  # route_rules, any existing host_rule/path_matcher blocks) so TF mirrors
  # your site as-is.
  #############################################

  # === NEW host rule for the API host ===
  host_rule {
    hosts        = [var.apigee_host]   # e.g., api.pueba-web-dev.com
    path_matcher = "apigee-matcher"
  }

  path_matcher {
    name            = "apigee-matcher"
    # All paths on the API host go to Apigee
    default_service = google_compute_backend_service.apigee_ingress_bs.self_link
  }
}
