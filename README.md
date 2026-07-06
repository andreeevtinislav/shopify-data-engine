# shopify-data-engine

A Shopify-to-Snowflake data platform, built end to end as a personal project: infrastructure as code, a Python ingestion pipeline, a dbt transformation layer, and production observability.

Data flows in three stages, each owned by its own top-level folder (structured as if each were its own repo):

```
Shopify Admin API  --->  ingestion/  --->  Snowflake RAW  --->  dbt/  --->  Snowflake STAGING
   (GraphQL)              (Python)          (JSON, MERGE-        (SQL)      (typed, tested
                                              upserted)                      models)
```

- **[`terraform/`](terraform/README.md)** — all infrastructure as code: Snowflake warehouse/database/schemas/tables/stage/roles, plus the ECS Fargate + Datadog observability stack the pipeline runs under in production. Provision this first.
- **[`ingestion/`](ingestion/README.md)** — Python pipeline that pulls Shopify orders and products via the GraphQL Admin API (bulk operations for historical backfill, cursor pagination for incremental syncs) and MERGE-upserts them into Snowflake as raw JSON.
- **[`dbt/`](dbt/README.md)** — transforms raw JSON into typed, tested staging models (bronze -> silver): one row per order/product plus flattened child tables for line items, refunds, and variants.

## What's covered

| Object | Ingestion | Staging (dbt) |
|---|---|---|
| Orders | backfill + incremental | `stg_shopify__orders`, `stg_shopify__order_line_items`, `stg_shopify__refunds` |
| Products | backfill + incremental | `stg_shopify__products`, `stg_shopify__product_variants` |

Marts (silver -> gold) are future work.

## Design notes worth calling out

- **Idempotent by construction.** Every load is a MERGE keyed on the Shopify object id, at every layer (RAW ingestion, dbt staging). Re-running any step, at any granularity, converges to the same state — safe for retries, backfills, and incremental overlap windows.
- **Watermark-based incremental sync.** A `_SYNC_STATE` table tracks the last successful watermark per object, with a small overlap window re-pulled on each run to cover updates that land just before the previous watermark.
- **Config-driven infrastructure.** Terraform modules are generic (`warehouse`, `database`, `table`, `stage`, `access`); adding a new table or role is a YAML edit in `environments/production/`, not new HCL.
- **Least-privilege by default.** Each service (ingestion, dbt) gets its own Snowflake role and service user, scoped to only the schemas it needs (`SHOPIFY_LOADER_ROLE` on `RAW`; `DBT_TRANSFORM_ROLE` read-only on `RAW`, read/write on `STAGING`).
- **Observability wired in from the start.** The ingestion pipeline runs as an ECS Fargate task with a Datadog Agent sidecar (APM via `ddtrace-run`, log collection via FireLens) — see `terraform/ecs/`.

## Stack

Python · Shopify GraphQL Admin API (Bulk Operations) · Snowflake · dbt · Terraform · AWS ECS Fargate · Datadog
