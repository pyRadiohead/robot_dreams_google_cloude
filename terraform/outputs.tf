output "data_lake_bucket_name" {
  description = "Name of the GCS data lake bucket"
  value       = google_storage_bucket.data_lake.name
}

output "data_lake_bucket_url" {
  description = "URL of the GCS data lake bucket"
  value       = google_storage_bucket.data_lake.url
}

output "scripts_bucket_name" {
  description = "Name of the scripts/DAGs GCS bucket"
  value       = google_storage_bucket.scripts_bucket.name
}

output "gold_dataset_id" {
  description = "BigQuery Gold dataset ID"
  value       = google_bigquery_dataset.gold.dataset_id
}

output "dataproc_service_account_email" {
  description = "Email of the Dataproc service account (use this for the SA key)"
  value       = google_service_account.dataproc_sa.email
}

# Uncomment when Composer is re-enabled:
# output "composer_service_account_email" {
#   value = google_service_account.composer_sa.email
# }
# output "composer_airflow_uri" {
#   value = google_composer_environment.composer.config[0].airflow_uri
# }
