# shopify-data-engine

Custom ingestion pipeline that loads Shopify data into Snowflake. v1 covers orders and line items only, landed as raw JSON — no transformation layer yet (that's a future dbt project).

## Setup

### 1. Shopify custom app

1. Shopify admin → **Settings → Apps and sales channels → Develop apps** → **Create an app**.
2. **Configuration → Admin API integration** → grant scope `read_orders`.
3. **Install app**, copy the Admin API access token (`shpat_...`) — shown once.

### 2. Snowflake infrastructure

Provisioned via Terraform, organized as reusable modules (`terraform/modules/{warehouse,database,table,stage,access}`) driven by per-environment YAML config (`terraform/environments/production/*.yml`).

#### Terraform admin credentials (one-time, permanent)

Terraform itself authenticates as a dedicated `TERRAFORM_ADMIN` service user via key-pair auth (`ACCOUNTADMIN` role) — set up once, never expires, no PAT regeneration needed. If it doesn't exist yet in your account:

```bash
openssl genrsa -out secrets/terraform_admin_key.p8 4096
openssl rsa -in secrets/terraform_admin_key.p8 -pubout -out secrets/terraform_admin_key.pub

# Run once via any existing ACCOUNTADMIN session (e.g. a short-lived PAT — see
# Snowsight > Settings > Authentication > Programmatic access tokens; if login
# fails with "Network policy is required", use that token's "Bypass requirement
# for network policy" option rather than opening up a network policy):
#   CREATE USER TERRAFORM_ADMIN TYPE = SERVICE
#     RSA_PUBLIC_KEY = '<contents of terraform_admin_key.pub, header/footer/newlines stripped>'
#     DEFAULT_ROLE = ACCOUNTADMIN;
#   GRANT ROLE ACCOUNTADMIN TO USER TERRAFORM_ADMIN;
```

`secrets/terraform_admin_key.p8` is gitignored — keep it, it's the permanent credential.

#### Running Terraform

The pipeline's own service user also authenticates with key-pair auth, so generate that key pair too and pass its public key in:

```bash
openssl genrsa -out secrets/snowflake_key.p8 4096
openssl rsa -in secrets/snowflake_key.p8 -pubout -out secrets/snowflake_key.pub

export SNOWFLAKE_ORGANIZATION_NAME="<org>"
export SNOWFLAKE_ACCOUNT_NAME="<account>"
export SNOWFLAKE_USER="TERRAFORM_ADMIN"
export SNOWFLAKE_AUTHENTICATOR="SNOWFLAKE_JWT"
export SNOWFLAKE_PRIVATE_KEY="$(cat secrets/terraform_admin_key.p8)"
export TF_VAR_pipeline_rsa_public_key=$(grep -v '^-----' secrets/snowflake_key.pub | tr -d '\n')

cd terraform/environments/production
terraform init
terraform plan
terraform apply
```

Keep `secrets/snowflake_key.p8` (the pipeline's private key) — its path goes into the pipeline's `.env` as `SNOWFLAKE_PRIVATE_KEY_PATH`.

This creates the `SHOPIFY_WH` warehouse, `SHOPIFY_DATA.RAW` schema, an internal stage, the `SHOPIFY_ORDERS_JSON` and `_SYNC_STATE` tables, and a least-privilege `SHOPIFY_LOADER_ROLE` + service user for the pipeline to run as. To add a new table, warehouse, or database object, edit the relevant `.yml` file in `environments/production/` — no HCL changes needed unless the shape of the config itself changes.

### 3. Pipeline config

```bash
cp .env.example .env
# fill in SHOPIFY_* and SNOWFLAKE_* values
```

### 4. Install and run

```bash
pip install -e ".[dev]"

# one-time historical backfill
sync-orders --mode backfill

# incremental sync (run repeatedly, e.g. via cron, once validated)
sync-orders --mode incremental
```

See the plan doc for the full design (API choice, sync algorithm, schema, verification steps).
