variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Bucket location/region (e.g., us-central1)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GKE zone for a zonal cluster"
  default     = "us-central1-a"
}

variable "region" {
  description = "Region"
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

variable "domain" {
  description = "FQDN for the load balancer (e.g., app.example.com)"
  type        = string
}

variable "ar_repo_name" {
  type        = string
  description = "Artifact Registry repository name"
  default     = "apps"
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
  default     = "web-apis"
}

variable "node_machine_type" {
  type        = string
  description = "GKE node machine type"
  default     = "e2-standard-4"
}

variable "vpc_self_link" {
  type        = string
  description = "Self link of the VPC network to attach the private zone to"
  default     = "projects/app-dev-468521/global/networks/default"
}
