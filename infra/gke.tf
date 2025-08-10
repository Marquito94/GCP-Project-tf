# Enable API (safe to keep even if enabled elsewhere)
resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"
}

# Regional Standard cluster (uses var.region)
resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.zone

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  release_channel {
    channel = "REGULAR"
  }

  # We'll attach our own managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "primary_pool" {
  name     = "primary-pool"
  cluster  = google_container_cluster.gke.name
  location = var.zone

  initial_node_count = 3

  autoscaling {
    min_node_count = 3
    max_node_count = 6
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type   = var.node_machine_type          # default "e2-standard-4"
    disk_type     = "pd-standard"
    disk_size_gb  = 25  
    service_account = data.google_compute_default_service_account.default.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Basic hardening
    metadata = {
      "disable-legacy-endpoints" = "true"
    }
    workload_metadata_config {
      mode = "GCE_METADATA"
    }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [
    google_container_cluster.gke,
    google_project_iam_member.nodes_ar_reader
  ]
}
