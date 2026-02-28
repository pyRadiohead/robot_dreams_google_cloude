# -------------------------------------------------------
# BigQuery Gold Dataset (Serving Layer)
# -------------------------------------------------------

resource "google_bigquery_dataset" "gold" {
  dataset_id    = "gold"
  friendly_name = "Gold Layer"
  description   = "Serving layer with enriched user profiles and final analytical tables"
  location      = var.location
}

# -------------------------------------------------------
# BigQuery External Tables pointing to Silver GCS data
# These allow querying Parquet data in GCS using BigQuery SQL
# without copying data into BigQuery storage.
# -------------------------------------------------------

resource "google_bigquery_table" "silver_sales_external" {
  dataset_id = google_bigquery_dataset.gold.dataset_id
  table_id   = "silver_sales"
  description = "External table over silver/sales Parquet partitioned by purchase_date"

  external_data_configuration {
    source_uris   = ["gs://${var.data_lake_bucket_name}/silver/sales/*"]
    source_format = "PARQUET"
    autodetect    = true

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "gs://${var.data_lake_bucket_name}/silver/sales/"
      require_partition_filter = false
    }
  }

  deletion_protection = false
}

resource "google_bigquery_table" "silver_customers_external" {
  dataset_id  = google_bigquery_dataset.gold.dataset_id
  table_id    = "silver_customers"
  description = "External table over silver/customers Parquet"

  external_data_configuration {
    source_uris   = ["gs://${var.data_lake_bucket_name}/silver/customers/*"]
    source_format = "PARQUET"
    autodetect    = true
  }

  deletion_protection = false
}

resource "google_bigquery_table" "silver_user_profiles_external" {
  dataset_id  = google_bigquery_dataset.gold.dataset_id
  table_id    = "silver_user_profiles"
  description = "External table over silver/user_profiles Parquet"

  external_data_configuration {
    source_uris   = ["gs://${var.data_lake_bucket_name}/silver/user_profiles/*"]
    source_format = "PARQUET"
    autodetect    = true
  }

  deletion_protection = false
}

# -------------------------------------------------------
# Gold table: user_profiles_enriched
# Will be populated by the enrich_user_profiles Airflow DAG.
# Defined here as a native BQ table so it persists across runs.
# -------------------------------------------------------

resource "google_bigquery_table" "user_profiles_enriched" {
  dataset_id          = google_bigquery_dataset.gold.dataset_id
  table_id            = "user_profiles_enriched"
  description         = "Enriched customer table combining silver.customers and silver.user_profiles"
  deletion_protection = false
}
