# Local Airflow Setup

Local Airflow running in Docker Compose, connected to real GCP services.

## Quick Start

### 1. Create your `.env` file
```bash
cp .env.example .env
# Edit .env if your project ID, bucket names, etc. differ
```

### 2. Create the GCP Service Account key
```bash
# After running terraform apply, create a key for the Dataproc SA:
gcloud iam service-accounts keys create airflow/gcp/sa-key.json \
  --iam-account=dataproc-spark-sa@robot-dream-course.iam.gserviceaccount.com
```

### 3. Start Airflow
```bash
# First time only — init the DB and create admin user:
docker compose run --rm airflow-init

# Start all services:
docker compose up -d

# Open the Web UI:
open http://localhost:8080
# Login: admin / admin (or whatever you set in .env)
```

### 4. Stop Airflow
```bash
docker compose down
# To also delete the postgres data volume:
docker compose down -v
```

## Directory Structure
```
airflow/
├── dags/           ← Your Airflow DAG files (auto-loaded)
├── logs/           ← Airflow task logs (gitignored)
├── plugins/        ← Custom Airflow plugins
├── config/
│   └── requirements.txt  ← Extra Python packages (GCP providers)
└── gcp/
    └── sa-key.json ← GCP Service Account key (gitignored, create manually)
```

## How it connects to GCP
The `GOOGLE_APPLICATION_CREDENTIALS` env var inside every container points
to `/opt/airflow/gcp/sa-key.json` — the service account key you created above.
The DAGs read `GCP_PROJECT_ID`, `DATA_LAKE_BUCKET`, etc. from `.env`.
