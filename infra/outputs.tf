output "service_account_email" {
  description = "Deployer service account email (for reference)"
  value       = google_service_account.deployer.email
}

output "service_account_key_json" {
  description = "Base64-encoded JSON key for the deployer SA (SENSITIVE). Store in GitHub secret GCP_SA_KEY."
  value       = google_service_account_key.deployer_key.private_key
  sensitive   = true
}

output "bucket_name" {
  value       = google_storage_bucket.site.name
  description = "Bucket name created for static website"
}

output "website_url" {
  value       = "http://storage.googleapis.com/${google_storage_bucket.site.name}/index.html"
  description = "Path-style website URL (public only if make_bucket_public=true)"
}
