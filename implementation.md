# Google Cloud Data Platform — Implementation Plan

## Project Overview

Migration of a data engineering project from AWS to GCP. The data platform ingests electronics sales data, processes it through a medallion architecture (Raw → Bronze → Silver → Gold), and enables analytical queries on customer purchases by state and age.

**Project ID:** `robot-dream-course`  
**Orchestration:** Local Apache Airflow (Docker) → Dataproc Serverless (PySpark) → BigQuery

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Google Cloud Storage                       │
│  gs://robot-dream-course-data-lake/                         │
│  ├── raw/           ← source CSVs and JSONLines             │
│  ├── bronze/        ← schema-on-read, all STRING fields     │
│  └── silver/        ← typed, cleaned, Parquet format        │
└─────────────────────────┬───────────────────────────────────┘
                          │ External Tables
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     BigQuery (gold dataset)                  │
│  ├── silver_sales (external)                                │
│  ├── silver_customers (external)                            │
│  ├── silver_user_profiles (external)                        │
│  └── user_profiles_enriched  ← native Gold table           │
└─────────────────────────────────────────────────────────────┘

Orchestration: Local Airflow (Docker) → DataprocCreateBatchOperator → Dataproc Serverless
```

### AWS → GCP Service Mapping

| AWS Service | GCP Equivalent | Notes |
|------------|----------------|-------|
| S3 | Cloud Storage (GCS) | Direct equivalent |
| Glue ETL | Dataproc Serverless | Serverless PySpark |
| Glue Data Catalog | BigQuery External Tables | Schema-on-read over GCS |
| Redshift | BigQuery | Serverless analytics warehouse |
| MWAA (Managed Airflow) | **Local Airflow (Docker)** | ⚠️ Cloud Composer = $300/mo |
| CloudFormation | Terraform | IaC standard |

---

## Cost Profile

| Resource | Free Tier | Expected Cost |
|----------|-----------|---------------|
| GCS | 5 GB free | ~$0 for this project |
| BigQuery | 10 GB / 1 TB queries free | ~$0 for this project |
| Dataproc Serverless | None | ~$0.05–0.10 per job run |
| Local Airflow | Free (runs locally) | $0 |
| Cloud Composer | ❌ None — **disabled** | Would cost $150–300+/mo |

---

## Infrastructure (Terraform)

> [!IMPORTANT]
> Before applying, run: `gcloud auth application-default login`

**Files in `terraform/`:**

| File | Purpose |
|------|---------|
| `main.tf` | Provider config (hashicorp/google ~> 5.0) |
| `variables.tf` | Variable declarations |
| `terraform.tfvars` | ⚠️ Gitignored — real values |
| `terraform.tfvars.example` | ✅ Committed — safe template |
| `apis.tf` | Enables Storage, BigQuery, Dataproc, IAM APIs |
| `storage.tf` | Data lake bucket + scripts bucket |
| `iam.tf` | `dataproc-spark-sa` service account + roles |
| `bigquery.tf` | Gold dataset + 3 external tables + enriched table |
| `composer.tf` | ☁️ Disabled — Cloud Composer (cost) |

**What Terraform provisions (Plan: 20 resources):**
- `robot-dream-course-data-lake` bucket with `raw/`, `bronze/`, `silver/`
- `robot-dream-course-scripts` bucket for PySpark scripts
- `gold` BigQuery dataset
- External tables: `silver_sales`, `silver_customers`, `silver_user_profiles`
- Native table: `user_profiles_enriched`
- Service account: `dataproc-spark-sa` with Storage, BigQuery, Dataproc roles

**Deploy:**
```bash
cd terraform
terraform plan   # preview
terraform apply  # create resources (~2 min)
```

---

## Local Airflow Setup

**Files:**

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Airflow 2.9.2 + LocalExecutor + Postgres |
| `airflow/config/requirements.txt` | `apache-airflow-providers-google` |
| `airflow/gcp/sa-key.json` | ⚠️ Gitignored — SA key (create manually) |
| `.env` | ⚠️ Gitignored — passwords and bucket names |
| `.env.example` | ✅ Committed — safe template |

**Start:**
```bash
# 1. Create SA key after terraform apply
gcloud iam service-accounts keys create airflow/gcp/sa-key.json \
  --iam-account=dataproc-spark-sa@robot-dream-course.iam.gserviceaccount.com

# 2. Configure environment
cp .env.example .env

# 3. First-time DB initialization
docker compose run --rm airflow-init

# 4. Start all services
docker compose up -d
# Web UI: http://localhost:8080  (admin/admin)
```

---

## Data Pipelines

### 1. `process_sales` — Daily Schedule
| Layer | Action |
|-------|--------|
| **Bronze** | Read `raw/sales/<date>/` CSV, all fields as `STRING`. Keep original column names: `CustomerId`, `PurchaseDate`, `Product`, `Price`. Write to `bronze/sales/`. |
| **Silver** | Read bronze. **Cleanse**: strip `$`/`USD` from `Price`. **Rename**: `client_id`, `purchase_date`, `product_name`, `price`. **Cast** to proper types. Write Parquet to `silver/sales/` **partitioned by `purchase_date`**. |

DAG: `airflow/dags/process_sales.py` ✅ created

### 2. `process_customers` — Daily Schedule
| Layer | Action |
|-------|--------|
| **Bronze** | Read full daily dump CSV from `raw/customers/`. All fields as `STRING`, original column names. Write to `bronze/customers/`. Use `MERGE`/overwrite to handle daily full-dump pattern. |
| **Silver** | Rename to: `client_id`, `first_name`, `last_name`, `email`, `registration_date`, `state`. Cast types. Write Parquet to `silver/customers/` (no partitioning). |

DAG: ⬜ to be created

### 3. `process_user_profiles` — Manual Trigger
| Layer | Action |
|-------|--------|
| **Silver** | Read JSONLine files from `raw/user_profiles/`. Data is clean — no cleansing needed. Write Parquet to `silver/user_profiles/`. |

DAG: ⬜ to be created

### 4. `enrich_user_profiles` — Manual Trigger (runs after pipeline 3)
| Layer | Action |
|-------|--------|
| **Gold** | SQL `MERGE` into `gold.user_profiles_enriched`. Fill missing `first_name`, `last_name`, `state` from `silver.user_profiles`. Append extra fields: `phone_number`, `age`, etc. |

DAG: ⬜ to be created  
Operator: `BigQueryInsertJobOperator`

---

## Analytical Query (Final Goal)

> **Which state sold the most TVs to customers aged 20–30 during the first decade of September?**

```sql
SELECT
  up.state,
  COUNT(*) AS tv_count
FROM `gold.user_profiles_enriched` up
JOIN `gold.silver_sales` s ON s.client_id = up.client_id
WHERE
  s.product_name = 'TV'
  AND DATE(s.purchase_date) BETWEEN '2022-09-01' AND '2022-09-10'
  AND up.age BETWEEN 20 AND 30
GROUP BY up.state
ORDER BY tv_count DESC
LIMIT 1;
```

---

## Security Checklist

| Item | Status |
|------|--------|
| `terraform.tfvars` gitignored | ✅ |
| `.env` gitignored | ✅ |
| `airflow/gcp/sa-key.json` gitignored | ✅ |
| `terraform/*.tfstate` gitignored | ✅ |
| `terraform/.terraform/` gitignored | ✅ |
| `terraform.tfvars.example` committed (no secrets) | ✅ |
| `.env.example` committed (no secrets) | ✅ |

---

## Verification Plan

### Infrastructure
```bash
terraform validate        # syntax check
terraform plan            # preview (should show ~20 resources)
terraform apply           # deploy
gcloud storage ls gs://robot-dream-course-data-lake/  # verify bucket
bq ls gold                # verify BQ dataset
```

### Pipelines
1. Upload data: `gcloud storage cp -r data gs://robot-dream-course-data-lake/raw`
2. Upload PySpark scripts: `gcloud storage cp -r spark_jobs gs://robot-dream-course-scripts/jobs/`
3. Trigger `process_sales` → verify Parquet in `silver/sales/`
4. Trigger `process_customers` → verify Parquet in `silver/customers/`
5. Trigger `process_user_profiles` → verify Parquet in `silver/user_profiles/`
6. Trigger `enrich_user_profiles` → verify `gold.user_profiles_enriched` in BigQuery
7. Run the analytical query in BigQuery console

### Outstanding Work
- [ ] Write `spark_jobs/process_sales.py` PySpark script
- [ ] Write `spark_jobs/process_customers.py` PySpark script
- [ ] Write `spark_jobs/process_user_profiles.py` PySpark script
- [ ] Create `airflow/dags/process_customers.py` DAG
- [ ] Create `airflow/dags/process_user_profiles.py` DAG
- [ ] Create `airflow/dags/enrich_user_profiles.py` DAG (BigQueryInsertJobOperator)
