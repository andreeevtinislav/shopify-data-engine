# shopify-data-engine

A Shopify-to-Snowflake data platform, built end to end as a personal project: infrastructure as code, a Python ingestion pipeline, a dbt transformation layer, and production observability.

Data flows in three stages, each owned by its own top-level folder (structured as if each were its own repo):

```
Shopify webhooks (push)  ─┐
                          ├─▶  ingestion/  ─▶  Snowflake RAW  ─▶  dbt/  ─▶  Snowflake STAGING
Shopify Admin API (poll) ─┘      (Python)         (JSON, MERGE-      (SQL)    (typed, tested
                                                    upserted)                  models)
                                                       │
                                                       ▼
                                          Stream + Task ─▶ RAW.ORDER_CHANGE_LOG
                                          (log-based CDC, independent of dbt)
```

Orders reach `RAW` two ways: Shopify webhooks (near-real-time push, the primary path) and a polling GraphQL sync (demoted to an infrequent reconciliation net, since webhook delivery isn't guaranteed). Both funnel through the same stage-then-MERGE write path. A Snowflake Stream + Task on `RAW.SHOPIFY_ORDERS_JSON` is a second, independent *reader* of that table — real log-based CDC, populating a lightweight change-log for low-latency downstream consumers without touching dbt's own incremental build.

- **[`terraform/`](terraform/README.md)** — Snowflake infrastructure as code: warehouse/database/schemas/tables/stage/streams/tasks/roles. Provision this first.
- **[`aws-infrastructure/`](aws-infrastructure/README.md)** — AWS infrastructure as code: ECR, the Lambda + API Gateway webhook receiver, the ECS Fargate + Datadog batch-sync task, Secrets Manager, and least-privilege IAM. Same modular/YAML pattern as `terraform/`, one level down (AWS instead of Snowflake).
- **[`ingestion/`](ingestion/README.md)** — Python pipeline that pulls Shopify orders and products via the GraphQL Admin API (bulk operations for historical backfill, cursor pagination for incremental syncs) and MERGE-upserts them into Snowflake as raw JSON.
- **[`dbt/`](dbt/README.md)** — transforms raw JSON into typed, tested staging models (bronze -> silver): one row per order/product plus flattened child tables for line items, refunds, and variants.

## What's covered

| Object | Ingestion | Staging (dbt) |
|---|---|---|
| Orders | backfill + incremental poll + webhooks (CDC) | `stg_shopify__orders`, `stg_shopify__order_line_items`, `stg_shopify__refunds` |
| Products | backfill + incremental | `stg_shopify__products`, `stg_shopify__product_variants` |

Marts (silver -> gold) are future work.

## Design notes worth calling out

- **Idempotent by construction.** Every load is a MERGE keyed on the Shopify object id, at every layer (RAW ingestion, dbt staging). Re-running any step, at any granularity, converges to the same state — safe for retries, backfills, and incremental overlap windows.
- **Watermark-based incremental sync.** A `_SYNC_STATE` table tracks the last successful watermark per object, with a small overlap window re-pulled on each run to cover updates that land just before the previous watermark.
- **Config-driven infrastructure, on both clouds.** Both `terraform/` (Snowflake) and `aws-infrastructure/` (AWS) use the same shape: generic modules driven by per-environment YAML; adding a new table, role, Lambda, or secret is a YAML edit, not new HCL.
- **Least-privilege by default.** Each service gets its own credential, scoped to only what it needs: `SHOPIFY_LOADER_ROLE` (Snowflake, RAW) for the poller, `SHOPIFY_WEBHOOK_ROLE` (Snowflake, RAW) for the webhook Lambda — a separate credential from the loader for blast-radius isolation — `DBT_TRANSFORM_ROLE` (Snowflake, read-only RAW / read-write STAGING) for dbt, and a dedicated IAM role per AWS resource (Lambda exec role scoped to exactly the 3 secrets + log group it uses).
- **Observability wired in from the start.** The batch sync runs as an ECS Fargate task with a Datadog Agent sidecar (APM via `ddtrace-run`, log collection via FireLens) — see `aws-infrastructure/`'s `ecs_task` module.
- **CDC done properly, in the two places it's actually possible.** Shopify is a hosted SaaS API — there's no transaction log to tail the way Debezium tails Postgres' WAL — so log-based CDC isn't available at the source. The realistic two-part equivalent: Shopify webhooks (event push) as the low-latency write path into `RAW`, with polling kept as a reconciliation net; and a genuine Snowflake Stream + Task pair on `RAW.SHOPIFY_ORDERS_JSON` as real log-based CDC one hop downstream, feeding `RAW.ORDER_CHANGE_LOG` without touching dbt's own incremental build.

## Stack

Python · Shopify GraphQL Admin API (Bulk Operations, Webhooks) · Snowflake (Streams, Tasks) · dbt · Terraform · AWS Lambda + API Gateway · AWS ECS Fargate · Datadog
