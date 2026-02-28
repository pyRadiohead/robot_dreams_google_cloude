variable "project_id" {
  description = "The GCP Project ID"
  type        = string
  default     = "robot-dream-course"
}

variable "region" {
  description = "Default region for regional resources"
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "Multi-region location for GCS and BigQuery"
  type        = string
  default     = "US"
}

variable "data_lake_bucket_name" {
  description = "Name of the GCS data lake bucket"
  type        = string
  default     = "robot-dream-course-data-lake"
}

variable "composer_env_name" {
  description = "Name of the Cloud Composer (Airflow) environment"
  type        = string
  default     = "data-platform-composer"
}

variable "composer_node_count" {
  description = "Number of nodes in the Composer environment"
  type        = number
  default     = 3
}
