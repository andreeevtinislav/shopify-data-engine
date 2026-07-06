# terraform

Provisions the infrastructure for the whole platform: the Snowflake side (warehouse, database, schemas, tables, stage, and a least-privilege role/service user for each of `../ingestion` and `../dbt`), and the AWS side the pipeline runs on in production (ECS Fargate + a Datadog Agent sidecar for APM, log collection, and metrics).

Snowflake resources are organized as reusable modules (`modules/{warehouse,database,table,stage,access}`) driven by per-environment YAML config (`environments/production/*.yml`). To add a new table, warehouse, or database object, edit the relevant `.yml` file in `environments/production/` — no HCL changes needed unless the shape of the config itself changes. `ecs/` (AWS/ECS/Datadog) is plain HCL, since it's a single task definition rather than a growing list of similarly-shaped objects.

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

This creates the `SHOPIFY_WH` warehouse, `SHOPIFY_DATA.RAW`/`STAGING` schemas, an internal stage, the `SHOPIFY_ORDERS_JSON`, `SHOPIFY_PRODUCTS_JSON`, and `_SYNC_STATE` tables, and two least-privilege roles + service users: `SHOPIFY_LOADER_ROLE` (read/write on `RAW`, for `../ingestion`) and `DBT_TRANSFORM_ROLE` (read-only on `RAW`, read/write on `STAGING`, for `../dbt`).

### 3. ECS + Datadog (production runtime)

`ecs/` provisions the ECS Fargate task that runs the ingestion pipeline in production, with a Datadog Agent sidecar for APM (`ddtrace-run`), log collection (via FireLens), and metrics. The Datadog API key is stored in AWS Secrets Manager, passed in at apply time rather than hard-coded:

```bash
cd ecs
terraform init
TF_VAR_dd_api_key="<datadog api key>" TF_VAR_ecr_image_uri="<ecr image uri>" terraform apply
```

## Layout

```
terraform/
├── secrets/                 # gitignored: terraform_admin_key.p8/.pub
├── modules/                  # reusable, environment-agnostic
│   ├── warehouse/
│   ├── database/              # database + schema only
│   ├── table/                  # separate module from database
│   ├── stage/
│   └── access/                  # role, grants, service user
├── environments/
│   └── production/
│       ├── providers.tf, variables.tf, outputs.tf, moved.tf
│       ├── warehouses.tf  + warehouses.yml
│       ├── databases.tf   + databases.yml
│       ├── tables.tf      + tables.yml
│       ├── stages.tf      + stages.yml
│       └── access.tf      + access.yml
└── ecs/                      # ECS Fargate task + Datadog Agent sidecar (production runtime)
    ├── main.tf                 # Secrets Manager secret + Datadog ECS Fargate module
    ├── providers.tf
    └── variables.tf
```
