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

variable "vpc_name" {
  type        = string
  description = "Name of the VPC Apigee will peer with (e.g., default)"
  default     = "default"
}

variable "apigee_env_name" {
  type        = string
  description = "Apigee environment name"
  default     = "dev"
}

variable "apigee_cidr" {
  type        = string
  default     = "172.31.48.0/22"
}

variable "apigee_envgroup_name" {
  type        = string
  description = "Apigee environment group name"
  default     = "public-eg"
}

variable "consumer_subnet_name" {
  type        = string
  default     = "default"
  description = "Not used for Apigee; kept for future if you also want a PSC endpoint in your VPC"
}

variable "apigee_host" {
  type        = string
  default     = "api.pueba-web-dev.com"
  description = "Public hostname (env group host) that clients hit"
}

variable "psc_nat_subnet_cidr" {
  type        = string
  default     = "172.21.0.0/24"
}

variable "producer_forwarding_rule" {
  type        = string
  description = "Self link of the INTERNAL_MANAGED Forwarding Rule created by GKE internal Ingress"
  default     = "https://www.googleapis.com/compute/v1/projects/app-dev-468521/regions/us-central1/forwardingRules/k8s2-fr-yrzx6l9k-apps-api-backend-ilb-ezq9xio1"
}

variable "ilb_subnet_name" {
  type        = string
  description = "Subnet name in var.region for the ILB IP (e.g., default)"
  default     = "default"
}

variable "ilb_ip_name" {
  type    = string
  default = "api-ilbv2-ip"
}

variable "proxy_only_cidr" {
  type        = string
  description = "UNUSED /23 or /24 for the ILB proxy-only subnet"
  default     = "172.20.0.0/23"
}
