# ingestion

Custom Python pipeline that loads Shopify data into Snowflake, landed as raw JSON. Currently covers:

- **orders** — orders, line items, refunds
- **products** — products, variants

Both are transformed further by the dbt staging layer in `../dbt`. Snowflake infrastructure for this pipeline is provisioned separately by `../terraform`.

In production this runs as an ECS Fargate task (see `../terraform/ecs/`) with a Datadog Agent sidecar: the CLI entrypoint is wrapped with `ddtrace-run` for APM, and logs ship to Datadog via FireLens. Locally, none of that is required — `ddtrace-run` is a no-op without a reachable agent.

## Setup

### 1. Shopify app

1. Shopify admin → **Settings → Apps and sales channels → Develop apps** → **Create an app** (or use the Dev Dashboard / Shopify CLI — see project history for the exact flow used).
2. Grant scopes `read_orders` and `read_all_orders` (the latter is required for full order history — `read_orders` alone only covers the last 60 days, and unapproved apps may be blocked from returning any order data at all on production stores; development stores auto-approve `read_all_orders`), plus `read_products` for the product/variant sync.
3. Install the app on your target store, copy the Admin API access token — shown once.

### 2. Snowflake infrastructure

Provisioned via Terraform — see `../terraform/README.md`. Run that first; this pipeline expects `SHOPIFY_DATA.RAW.SHOPIFY_ORDERS_JSON`, `SHOPIFY_PRODUCTS_JSON`, `_SYNC_STATE`, and the `SHOPIFY_STAGE` stage to already exist.

### 3. Pipeline config

```bash
cp .env.example .env
# fill in SHOPIFY_* values from step 1

# Snowflake key-pair auth: point SNOWFLAKE_PRIVATE_KEY_PATH at the private key
# whose public half Terraform granted access to (see ../terraform/README.md step 2)
```

### 4. Install and run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"

# one-time historical backfill (defaults to --object orders)
sync-orders --mode backfill
sync-orders --object products --mode backfill

# incremental sync (run repeatedly, e.g. via cron, once validated)
sync-orders --mode incremental
sync-orders --object products --mode incremental
```

## Layout

```
ingestion/
├── secrets/                       # gitignored: snowflake_key.p8/.pub
├── src/shopify_engine/
│   ├── config.py                    # Settings from .env
│   ├── shopify/                       # GraphQL client, bulk ops, queries
│   ├── snowflake/                      # connection, stage/MERGE loader
│   ├── extractors/                      # orders.py, products.py: backfill/incremental extraction
│   ├── sync/                              # watermark state + orchestration (dispatches by --object)
│   └── cli.py
├── scripts/sync_orders.py            # thin entrypoint
└── tests/
```
