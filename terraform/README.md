# terraform

Provisions the Snowflake side of the platform: warehouse, database, schemas, tables, stage, streams/tasks, and a least-privilege role/service user for each of `../ingestion`'s two write paths and `../dbt`. The AWS side the pipeline runs on in production (ECS Fargate + Datadog for the batch sync, Lambda + API Gateway for the webhook receiver) lives in `../aws-infrastructure` instead — see that folder's README.

Resources are organized as reusable modules (`modules/{warehouse,database,table,stage,stream,task,access}`) driven by per-environment YAML config (`environments/production/*.yml`). To add a new table, stream, task, warehouse, or database object, edit the relevant `.yml` file in `environments/production/` — no HCL changes needed unless the shape of the config itself changes.

## Setup

### 1. Terraform admin credentials (one-time, permanent)

Terraform authenticates as a dedicated `TERRAFORM_ADMIN` service user via key-pair auth (`ACCOUNTADMIN` role) — set up once, never expires, no token regeneration needed. If it doesn't exist yet in your account:

```bash
openssl genrsa -out secrets/terraform_admin_key.p8 4096
openssl rsa -in secrets/terraform_admin_key.p8 -pubout -out secrets/terraform_admin_key.pub

# Run once via any existing ACCOUNTADMIN session (e.g. a short-lived Programmatic
# Access Token — see Snowsight > Settings > Authentication > Programmatic access
# tokens; if login fails with "Network policy is required", use that token's
# "Bypass requirement for network policy" option rather than opening up a
# network policy):
#   CREATE USER TERRAFORM_ADMIN TYPE = SERVICE
#     RSA_PUBLIC_KEY = '<contents of terraform_admin_key.pub, header/footer/newlines stripped>'
#     DEFAULT_ROLE = ACCOUNTADMIN;
#   GRANT ROLE ACCOUNTADMIN TO USER TERRAFORM_ADMIN;
```

`secrets/terraform_admin_key.p8` is gitignored — keep it, it's the permanent credential.

### 2. Run Terraform

The pipeline's own service user also authenticates with key-pair auth, so generate that key pair too (its public key is what Terraform grants access to; the private key goes into `../ingestion/.env`):

```bash
openssl genrsa -out ../ingestion/secrets/snowflake_key.p8 4096
openssl rsa -in ../ingestion/secrets/snowflake_key.p8 -pubout -out ../ingestion/secrets/snowflake_key.pub

export SNOWFLAKE_ORGANIZATION_NAME="<org>"
export SNOWFLAKE_ACCOUNT_NAME="<account>"
export SNOWFLAKE_USER="TERRAFORM_ADMIN"
export SNOWFLAKE_AUTHENTICATOR="SNOWFLAKE_JWT"
export SNOWFLAKE_PRIVATE_KEY="$(cat secrets/terraform_admin_key.p8)"
export TF_VAR_pipeline_rsa_public_key=$(grep -v '^-----' ../ingestion/secrets/snowflake_key.pub | tr -d '\n')

cd environments/production
terraform init
terraform plan
terraform apply
```

This creates the `SHOPIFY_WH` warehouse, `SHOPIFY_DATA.RAW`/`STAGING`/`SNAPSHOTS` schemas, an internal stage, the `SHOPIFY_ORDERS_JSON`, `SHOPIFY_PRODUCTS_JSON`, `ORDER_CHANGE_LOG`, and `_SYNC_STATE` tables, a stream (`SHOPIFY_ORDERS_JSON_STREAM`) + task (`ORDER_CHANGE_LOG_TASK`) pair implementing log-based CDC from `SHOPIFY_ORDERS_JSON` into `ORDER_CHANGE_LOG` (independent of dbt — see root `README.md`'s "Design notes"), and three least-privilege roles + service users: `SHOPIFY_LOADER_ROLE` (read/write on `RAW`, for `../ingestion`'s polling sync), `SHOPIFY_WEBHOOK_ROLE` (read/write on `RAW`, for `../ingestion`'s webhook receiver Lambda — a separate credential from the loader role for blast-radius isolation), and `DBT_TRANSFORM_ROLE` (read-only on `RAW`, read/write on `STAGING` and `SNAPSHOTS`, for `../dbt` — `SNAPSHOTS` holds `../dbt`'s SCD Type 2 order-status history).

To provision the new webhook role's service user, generate its key pair the same way as the pipeline's:
```bash
openssl genrsa -out ../ingestion/secrets/webhook_key.p8 4096
openssl rsa -in ../ingestion/secrets/webhook_key.p8 -pubout -out ../ingestion/secrets/webhook_key.pub
export TF_VAR_webhook_rsa_public_key=$(grep -v '^-----' ../ingestion/secrets/webhook_key.pub | tr -d '\n')
```
Unlike the pipeline/dbt keys, `webhook_key.p8`'s contents don't go into a local `.env` — they go into a Secrets Manager secret provisioned by `../aws-infrastructure`, since the consumer is a Lambda, not a long-lived process reading a local file. See `../aws-infrastructure/README.md` for the rest of the deployment (ECR, Lambda, API Gateway, ECS, Secrets Manager).

## Layout

```
terraform/
├── secrets/                 # gitignored: terraform_admin_key.p8/.pub
├── modules/                  # reusable, environment-agnostic
│   ├── warehouse/
│   ├── database/              # database + schema only
│   ├── table/                  # separate module from database
│   ├── stage/
│   ├── stream/                  # snowflake_stream_on_table
│   ├── task/                     # snowflake_task
│   └── access/                    # role, grants, service user
└── environments/
    └── production/
        ├── providers.tf, variables.tf, outputs.tf, moved.tf
        ├── warehouses.tf  + warehouses.yml
        ├── databases.tf   + databases.yml
        ├── tables.tf      + tables.yml
        ├── stages.tf      + stages.yml
        ├── streams.tf     + streams.yml
        ├── tasks.tf       + tasks.yml
        └── access.tf      + access.yml
```
