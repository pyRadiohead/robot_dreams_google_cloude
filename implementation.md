# Google Cloud Architecture Implementation Plan

The goal is to design a data platform architecture mapping the final project requirements from the `README.md` to a modern Google Cloud (GCP) stack, replacing AWS services with their GCP equivalents. This plan documents the service mapping, architecture, and verification strategy.

## User Review Required
> [!IMPORTANT]
> The original setup used AWS CloudFormation. While Google Cloud offers native Cloud Deployment Manager, **Terraform** is the general industry standard for Infrastructure-as-Code on GCP. I propose using Terraform instead of Deployment Manager. Please confirm if this is acceptable or if you'd prefer to stick to native GCP Deployment Manager.

## Proposed Changes
Instead of AWS, we will build the data workflow on Google Cloud using the following service mapping:

| Original AWS Service | Google Cloud Alternative | Rationale |
| ----------- | ------------------------ | --------- |
| S3 (Buckets) | Google Cloud Storage (GCS) | GCS is the direct equivalent of S3 for object storage and data lakes. |
| AWS Glue (ETL, PySpark) | Dataproc Serverless for Spark | Best equivalent for serverless PySpark execution, avoiding the need to manually manage clusters. |
| AWS Glue Data Catalog | BigQuery External Tables | For "schema-on-read" we will use BigQuery External Tables over GCS, which removes the need for a separate crawler process entirely. |
| Amazon Redshift | Google BigQuery | BigQuery is the primary GCP data warehouse solution and excels at analytical workloads on large datasets. |
| AWS CloudFormation | Terraform | Adopting Terraform as the primary IaC tool. |
| Managed Airflow (MWAA) | Google Cloud Composer | Fully managed Airflow on GCP for orchestrating the jobs. |

### Infrastructure (IaC)
- Create a `main.tf` configuration (Terraform) replacing `DataPlatform.yaml`.
- Provision a GCS Bucket for the Data Lake (`[user]-data-lake-bucket`).
- Provision a BigQuery Dataset for the serving (Gold) layer.
- Ensure Cloud Composer Environment is provisioned for Airflow orchestration.
- Configure Service Accounts with necessary roles for Dataproc Serverless and Composer to access GCS and BigQuery.

### Data Ingestion Layer
Instead of `aws s3 cp`, we will use the Google Cloud Storage CLI (`gcloud storage`) to upload the initial raw files:
```bash
gcloud storage cp --recursive data gs://<DataLakeBucketName>/raw
```

### Transformation & Processing Pipelines (Bronze ➔ Silver)
- Instead of AWS Glue we will orchestrate serverless PySpark jobs via Cloud Composer utilizing `DataprocCreateBatchOperator`.
- The PySpark jobs corresponding to `process_sales`, `process_customers`, and `process_user_profiles` will read from GCS `raw`, cast properties to `STRING`, clean the data, partition where required (e.g. by date for `sales`), and write to GCS in `silver` using Parquet format.

### Data Warehouse & Serving (Gold)
- For the `gold` layer dataset (`enrich_user_profiles` pipeline), since it requires the `MERGE` operation, we will execute a SQL job directly in BigQuery using Airflow's `BigQueryInsertJobOperator`.
- We will define BigQuery External Tables pointing to our structured `silver` GCS Parquet data so they can be queried via standard SQL.

## Verification Plan

### Automated Tests
- Validate that `terraform apply` successfully executes and creates GCS, BigQuery, and Composer resources without errors.
- Run `gcloud storage cp` to ensure ingestion data behaves as expected.

### Manual Verification
- Manually trigger `process_sales`, `process_customers`, and `process_user_profiles` DAGs inside Cloud Composer.
- Check Dataproc Batches UI for job completions and verify the Parquet outputs and partitions in the `silver` GCS path.
- Trigger the `enrich_user_profiles` DAG and check if the combined table in BigQuery Gold layer is accurately populated.
- Run the required analytical query in BigQuery: *Which state sold the most TVs to buyers aged 20-30 during the first decade of September?* to ensure the entire pipeline generated the correct final results.
