variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Bucket location/region (e.g., us-central1)"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Single bucket name for the static website"
  type        = string
}

variable "main_page" {
  description = "Website main page"
  type        = string
  default     = "index.html"
}

variable "error_page" {
  description = "Website 404 page"
  type        = string
  default     = "404.html"
}

variable "make_bucket_public" {
  description = "If true, grant allUsers objectViewer"
  type        = bool
  default     = true
}

variable "deployer_sa_id" {
  description = "Service account ID (short), e.g., web-deployer"
  type        = string
  default     = "web-deployer"
}
