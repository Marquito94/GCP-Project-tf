output "workload_identity_provider" {
  description = "Value for GCP_WORKLOAD_IDP secret in GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.gh_provider.name
}

output "service_account_email" {
  description = "Value for GCP_SERVICE_ACCOUNT secret in GitHub Actions"
  value       = google_service_account.gh_deployer.email
}

output "bucket_urls" {
  description = "Public website URLs"
  value = {
    for k, b in google_storage_bucket.site :
    k => "http://storage.googleapis.com/${b.name}/index.html"
  }
}
