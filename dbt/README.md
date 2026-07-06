# dbt

dbt project that transforms raw Shopify data landed by `../ingestion` into typed,
query-ready models. v1 (this pass) covers the staging layer only (bronze -> silver);
marts/dim-fact (silver -> gold) are future work.

Also includes one snapshot (`snapshots/snapshot_shopify__orders.sql`) tracking order
status history (SCD Type 2) — see "Snapshots" below.

Note: `RAW.ORDER_CHANGE_LOG` (a CDC change-log populated by a Snowflake Stream +
Task, provisioned in `../terraform`) also lives in `RAW` but is intentionally
**not** a dbt source — it's a separate, low-latency consumer of
`SHOPIFY_ORDERS_JSON`, unrelated to this project's own incremental build off
the same table. Don't be surprised it's un-sourced here.

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

## Snapshots (order status history)

`snapshots/snapshot_shopify__orders.sql` tracks `financial_status`, `fulfillment_status`,
and `cancelled_at` on `stg_shopify__orders` as SCD Type 2 history: each distinct
version of an order's status gets its own row, bounded by `dbt_valid_from`/
`dbt_valid_to` (`NULL` = current). A return shows up as `financial_status` moving to
`PARTIALLY_REFUNDED`/`REFUNDED` — individual refund events themselves are already an
append-only log in `stg_shopify__refunds` and don't need their own snapshot.

**Important:** `dbt snapshot` is a separate command — it is *not* part of `dbt run` or
`dbt test` and needs its own schedule to actually accumulate history:

```bash
dbt run --select +stg_shopify__orders  # refresh STAGING first — snapshot reads from it
dbt snapshot
```

Snapshotting only captures whatever `stg_shopify__orders` looks like *at the moment it
runs* — it can't retroactively reconstruct a transition that happened and reversed
between two snapshot runs (e.g. fulfilled-then-unfulfilled within the same gap won't
show as two rows if you only ever see the end state). Run it often enough relative to
how frequently order status actually changes. No scheduler is wired up for this yet —
same gap as the ingestion poller's cadence (see root `README.md`).

## Layout

```
dbt/
├── secrets/                       # gitignored: dbt_transform_key.p8/.pub
├── snapshots/
│   ├── snapshot_shopify__orders.sql # SCD Type 2 order status history
│   └── schema.yml                     # column docs + tests
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
