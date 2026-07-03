# shopify-data-engine

Custom ingestion pipeline that loads Shopify data into Snowflake. v1 covers orders and line items only, landed as raw JSON — no transformation layer yet (that's a future dbt project).

## Setup

### 1. Shopify custom app

1. Shopify admin → **Settings → Apps and sales channels → Develop apps** → **Create an app**.
2. **Configuration → Admin API integration** → grant scope `read_orders`.
3. **Install app**, copy the Admin API access token (`shpat_...`) — shown once.

### 2. Snowflake infrastructure

Provisioned via Terraform, organized as reusable modules (`terraform/modules/{warehouse,database,table,stage,access}`) driven by per-environment YAML config (`terraform/environments/production/*.yml`). Requires admin-level Snowflake credentials (`ACCOUNTADMIN`), supplied as `SNOWFLAKE_*` environment variables — see `terraform/environments/production/providers.tf`.

The pipeline's service user authenticates with key-pair auth, so generate a key pair first and pass the public key in:

```bash
openssl genrsa -out snowflake_key.p8 4096
openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
export TF_VAR_pipeline_rsa_public_key=$(grep -v '^-----' snowflake_key.pub | tr -d '\n')

cd terraform/environments/production
terraform init
terraform plan
terraform apply
```

Keep `snowflake_key.p8` (the private key) — its path goes into the pipeline's `.env` as `SNOWFLAKE_PRIVATE_KEY_PATH`.

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
