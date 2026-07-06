# dbt

dbt project that transforms raw Shopify data landed by `../ingestion` into typed,
query-ready models. v1 (this pass) covers the staging layer only (bronze -> silver);
marts/dim-fact (silver -> gold) are future work.

## Setup

### 1. Snowflake infrastructure

Provisioned via Terraform — see `../terraform/README.md`. This project expects
`SHOPIFY_DATA.STAGING` and the `DBT_TRANSFORM_ROLE`/`DBT_TRANSFORM_SVC` service user
to already exist, with read-only access to `SHOPIFY_DATA.RAW` and full access to
`SHOPIFY_DATA.STAGING`.

### 2. Connection config

```bash
cp .env.example .env
cp profiles.yml.example profiles.yml
# fill in .env with the DBT_TRANSFORM_SVC key-pair path etc.
export DBT_PROFILES_DIR=$(pwd)
set -a && source .env && set +a
```

`profiles.yml` stays project-local (via `DBT_PROFILES_DIR`) rather than the
dbt-community-default `~/.dbt/profiles.yml`, consistent with this repo's
"each folder is its own repo" convention — every credential field in it is an
`env_var()` reference, so the file itself is safe to keep gitignored without
losing portability.

### 3. Install and run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

dbt debug
dbt run
dbt test
```

## Layout

```
dbt/
├── secrets/                       # gitignored: dbt_transform_key.p8/.pub
└── models/staging/shopify/
    ├── _shopify__sources.yml       # source def + freshness
    ├── schema.yml                    # column docs + tests
    ├── stg_shopify__orders_json.sql
    ├── stg_shopify__orders.sql
    ├── stg_shopify__order_line_items.sql
    ├── stg_shopify__refunds.sql
    ├── stg_shopify__products_json.sql
    ├── stg_shopify__products.sql
    └── stg_shopify__product_variants.sql
```
