# Single GCS Static Website (Terraform + GitHub Actions, JSON key)

This package provisions **one GCS bucket** for a static website with multiple paths,
and a **single Service Account** with a **JSON key** for GitHub Actions deploys.

## Terraform backend
Expects an existing backend:
- bucket: `tf_state_dev1`
- prefix: `state`

## Apply
```bash
cd infra
terraform init

terraform apply           -var="project_id=YOUR_PROJECT_ID"           -var="bucket_name=your-website-bucket"
```

> The output includes `service_account_key_json` (sensitive). Copy its value and store it in your GitHub repo secret `GCP_SA_KEY`. Also create a secret `GCS_BUCKET` with the bucket name.

## GitHub Actions
The workflow at `.github/workflows/deploy-static.yml` uses the JSON key:
- Set repo secret **GCP_SA_KEY** to the TF output `service_account_key_json`.
- Set repo secret **GCS_BUCKET** to your bucket name.

On every push to `main`, it will sync repository files to the bucket.

## Security notes
- Treat the JSON key like a password. Rotate it by tainting/removing the `google_service_account_key` resource and re-applying.
- For production, consider using Workload Identity (OIDC) instead of long-lived keys.
