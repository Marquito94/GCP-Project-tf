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

output "apigee_envgroup_host" {
  value       = var.apigee_host
  description = "Public hostname your frontend should call (points to Env Group LB)."
}
