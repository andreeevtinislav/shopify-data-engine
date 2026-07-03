# terraform

Provisions the Snowflake infrastructure (warehouse, database, schema, tables, stage, and the pipeline's runtime role/service user) for the Shopify ingestion pipeline in `../ingestion`.

Organized as reusable modules (`modules/{warehouse,database,table,stage,access}`) driven by per-environment YAML config (`environments/production/*.yml`). To add a new table, warehouse, or database object, edit the relevant `.yml` file in `environments/production/` — no HCL changes needed unless the shape of the config itself changes.

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

This creates the `SHOPIFY_WH` warehouse, `SHOPIFY_DATA.RAW` schema, an internal stage, the `SHOPIFY_ORDERS_JSON` and `_SYNC_STATE` tables, and a least-privilege `SHOPIFY_LOADER_ROLE` + service user for the pipeline to run as.

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
└── environments/
    └── production/
        ├── providers.tf, variables.tf, outputs.tf, moved.tf
        ├── warehouses.tf  + warehouses.yml
        ├── databases.tf   + databases.yml
        ├── tables.tf      + tables.yml
        ├── stages.tf      + stages.yml
        └── access.tf      + access.yml
```
