# -------------------------------------------------------
# Cloud Composer (Managed Airflow) — DISABLED
# -------------------------------------------------------
# ⚠️  COST WARNING: Cloud Composer costs ~$150–300+/month
# because it provisions a GKE cluster underneath, charged 24/7.
#
# We use local Airflow via Docker Compose instead.
# Local Airflow connects to real GCP services (Dataproc, BigQuery, GCS)
# for free. See docker-compose.yml and airflow/README.md.
#
# To re-enable Cloud Composer:
#  1. Uncomment the resource block below
#  2. Uncomment the composer_sa resource in iam.tf
#  3. Uncomment the composer outputs in outputs.tf
#  4. Run: terraform apply
# -------------------------------------------------------

# resource "google_composer_environment" "composer" {
#   name   = var.composer_env_name
#   region = var.region
#
#   config {
#     software_config {
#       image_version = "composer-2-airflow-2"
#
#       pypi_packages = {
#         "apache-airflow-providers-google" = ">=10.0.0"
#       }
#
#       env_variables = {
#         DATA_LAKE_BUCKET = var.data_lake_bucket_name
#         GCP_PROJECT      = var.project_id
#         GCP_REGION       = var.region
#         BQ_DATASET       = "gold"
#       }
#     }
#
#     node_config {
#       # service_account = google_service_account.composer_sa.email
#     }
#   }
# }
