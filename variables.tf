variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Default location/region for resources (e.g., us-central1)"
  type        = string
  default     = "us-central1"
}

variable "buckets" {
  description = "Map of website buckets to create. Key = bucket name; value = object with main/error pages."
  type = map(object({
    main_page  = string
    error_page = string
  }))
  default = {
    "your-dev-bucket" = {
      main_page  = "index.html"
      error_page = "404.html"
    }
    "your-prod-bucket" = {
      main_page  = "index.html"
      error_page = "404.html"
    }
  }
}

variable "make_buckets_public" {
  description = "If true, grant allUsers objectViewer"
  type        = bool
  default     = true
}

variable "github_owner" {
  description = "GitHub org/user"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "wip_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "gh-pool"
}

variable "wip_provider_id" {
  description = "Workload Identity Pool Provider ID"
  type        = string
  default     = "gh-provider"
}
