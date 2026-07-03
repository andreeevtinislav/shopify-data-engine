# ingestion

Custom Python pipeline that loads Shopify orders into Snowflake. v1 covers orders and line items only, landed as raw JSON — no transformation layer yet (that's a future dbt project). Snowflake infrastructure for this pipeline is provisioned separately by `../terraform`.

## Setup

### 1. Shopify app

1. Shopify admin → **Settings → Apps and sales channels → Develop apps** → **Create an app** (or use the Dev Dashboard / Shopify CLI — see project history for the exact flow used).
2. Grant scopes `read_orders` and `read_all_orders` (the latter is required for full order history — `read_orders` alone only covers the last 60 days, and unapproved apps may be blocked from returning any order data at all on production stores; development stores auto-approve `read_all_orders`).
3. Install the app on your target store, copy the Admin API access token — shown once.

### 2. Snowflake infrastructure

Provisioned via Terraform — see `../terraform/README.md`. Run that first; this pipeline expects `SHOPIFY_DATA.RAW.SHOPIFY_ORDERS_JSON`, `_SYNC_STATE`, and the `SHOPIFY_STAGE` stage to already exist.

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

# one-time historical backfill
sync-orders --mode backfill

# incremental sync (run repeatedly, e.g. via cron, once validated)
sync-orders --mode incremental
```

## Layout

```
ingestion/
├── secrets/                       # gitignored: snowflake_key.p8/.pub
├── src/shopify_engine/
│   ├── config.py                    # Settings from .env
│   ├── shopify/                       # GraphQL client, bulk ops, queries
│   ├── snowflake/                      # connection, stage/MERGE loader
│   ├── extractors/orders.py             # backfill/incremental extraction
│   ├── sync/                              # watermark state + orchestration
│   └── cli.py
├── scripts/sync_orders.py            # thin entrypoint
└── tests/
```
