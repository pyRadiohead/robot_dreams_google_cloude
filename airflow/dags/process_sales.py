"""
process_sales DAG
─────────────────
Orchestrates the bronze → silver transformation for sales data using
Dataproc Serverless (PySpark). The PySpark script path must be uploaded
to the scripts GCS bucket before running this DAG.

Steps:
  1. Upload the PySpark job to GCS (done once, outside this DAG)
  2. This DAG submits a Dataproc Serverless batch job
  3. Dataproc reads raw/sales → writes bronze/sales → writes silver/sales
"""

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.google.cloud.operators.dataproc import (
    DataprocCreateBatchOperator,
    DataprocDeleteBatchOperator,
)

# ── Config from environment variables (set in docker-compose.yml) ──────
PROJECT_ID     = os.environ.get("GCP_PROJECT_ID", "robot-dream-course")
REGION         = os.environ.get("GCP_REGION", "us-central1")
DATA_LAKE      = os.environ.get("DATA_LAKE_BUCKET", "robot-dream-course-data-lake")
SCRIPTS_BUCKET = os.environ.get("SCRIPTS_BUCKET", "robot-dream-course-scripts")

BATCH_ID       = "process-sales-{{ ds_nodash }}"
PYSPARK_URI    = f"gs://{SCRIPTS_BUCKET}/jobs/process_sales.py"

default_args = {
    "owner": "data-team",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "depends_on_past": False,
}

with DAG(
    dag_id="process_sales",
    description="Bronze → Silver transformation for sales data via Dataproc Serverless",
    schedule_interval="@daily",
    start_date=datetime(2024, 9, 1),
    catchup=False,
    default_args=default_args,
    tags=["sales", "bronze", "silver"],
) as dag:

    submit_job = DataprocCreateBatchOperator(
        task_id="submit_pyspark_batch",
        project_id=PROJECT_ID,
        region=REGION,
        batch_id=BATCH_ID,
        batch={
            "pyspark_batch": {
                "main_python_file_uri": PYSPARK_URI,
                "args": [
                    f"--input=gs://{DATA_LAKE}/raw/sales/",
                    f"--bronze_output=gs://{DATA_LAKE}/bronze/sales/",
                    f"--silver_output=gs://{DATA_LAKE}/silver/sales/",
                ],
            },
            "runtime_config": {
                "version": "2.1",
            },
            "environment_config": {
                "execution_config": {
                    # Dataproc Serverless will use the ADC / service account
                    # credentials from the environment
                }
            },
        },
    )

    cleanup = DataprocDeleteBatchOperator(
        task_id="cleanup_batch",
        project_id=PROJECT_ID,
        region=REGION,
        batch_id=BATCH_ID,
        trigger_rule="all_done",  # cleanup even on failure
    )

    submit_job >> cleanup
