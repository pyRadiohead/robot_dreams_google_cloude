# -------------------------------------------------------
# Cloud Storage Data Lake Bucket
# -------------------------------------------------------

resource "google_storage_bucket" "data_lake" {
  name                        = var.data_lake_bucket_name
  location                    = var.location
  force_destroy               = true
  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90  # Clean up raw files older than 90 days (optional)
    }
  }
}

# -------------------------------------------------------
# Folder "placeholders" to create the data lake structure
# GCS doesn't have real folders; these empty objects act as markers.
# -------------------------------------------------------

resource "google_storage_bucket_object" "raw_folder" {
  name    = "raw/"
  bucket  = google_storage_bucket.data_lake.name
  content = " "
}

resource "google_storage_bucket_object" "bronze_folder" {
  name    = "bronze/"
  bucket  = google_storage_bucket.data_lake.name
  content = " "
}

resource "google_storage_bucket_object" "silver_folder" {
  name    = "silver/"
  bucket  = google_storage_bucket.data_lake.name
  content = " "
}

# -------------------------------------------------------
# Separate bucket to store PySpark job scripts and Airflow DAGs
# -------------------------------------------------------

resource "google_storage_bucket" "scripts_bucket" {
  name                        = "${var.project_id}-scripts"
  location                    = var.location
  force_destroy               = true
  uniform_bucket_level_access = true
}
