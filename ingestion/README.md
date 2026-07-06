# ingestion

Custom Python pipeline that loads Shopify data into Snowflake, landed as raw JSON. Currently covers:

- **orders** — orders, line items, refunds. Orders reach `RAW` two ways: a Shopify webhook receiver (`src/shopify_engine/webhook/`, near-real-time push, the primary path) and this same package's polling sync (demoted to an infrequent reconciliation net — webhook delivery isn't guaranteed exactly-once). Both write through the same stage-then-MERGE path (`snowflake/loader.py`).
- **products** — products, variants

Both are transformed further by the dbt staging layer in `../dbt`. Snowflake infrastructure for this pipeline is provisioned separately by `../terraform`.

In production this runs as an ECS Fargate task (see `../aws-infrastructure`'s `ecs_task` module) with a Datadog Agent sidecar: the CLI entrypoint is wrapped with `ddtrace-run` for APM, and logs ship to Datadog via FireLens. Locally, none of that is required — `ddtrace-run` is a no-op without a reachable agent.

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

# incremental sync (run repeatedly, e.g. via cron, once validated — now a
# reconciliation net alongside webhooks rather than the primary path)
sync-orders --mode incremental
sync-orders --object products --mode incremental
```

### 5. Webhooks (orders CDC)

The webhook receiver itself is a separate Lambda (provisioned by `../aws-infrastructure`), but registering Shopify's webhook subscriptions against it is done from here, since it reuses the same `ShopifyGraphQLClient`/`Settings`:

```bash
# after `terraform apply` in ../aws-infrastructure/environments/production (its
# webhook_callback_url output gives you the URL)
register-shopify-webhooks --callback-url "https://<api-id>.execute-api.<region>.amazonaws.com/webhooks/shopify"
```

This registers `ORDERS_CREATE`, `ORDERS_UPDATED`, `ORDERS_CANCELLED`, and `REFUNDS_CREATE`. It's idempotent — safe to re-run; already-registered topics for that callback URL are skipped. Shopify's `WebhookSubscriptionInput` has no way to shape the delivered payload (confirmed against the live Admin API — an earlier attempt at passing a custom `query` argument was rejected outright), so every topic delivers Shopify's default JSON shape. The handler always re-fetches the full order via `ORDER_BY_ID_QUERY` regardless of topic, keeping exactly one payload shape ever written to `RAW.SHOPIFY_ORDERS_JSON`.

Building/pushing the Lambda's container image (`Dockerfile.webhook`) is a manual step for now — no CI pipeline exists yet in this repo. Build with `--provenance=false --sbom=false`: modern `docker buildx` defaults to producing an OCI manifest-list with attestations, which Lambda's container image support rejects with `InvalidParameterValueException: ... media type ... is not supported`.
```bash
docker build --platform linux/amd64 --provenance=false --sbom=false -f Dockerfile.webhook -t <ecr-repo>:<tag> .
docker push <ecr-repo>:<tag>
```
After pushing a new image to an existing tag (e.g. re-pushing `:latest`), Terraform won't detect the change (the URI string is identical) — force it with `aws lambda update-function-code --function-name shopify-webhook-receiver --image-uri <ecr-repo>:<tag>`.

## Layout

```
ingestion/
├── secrets/                       # gitignored: snowflake_key.p8/.pub
├── Dockerfile.webhook               # webhook receiver Lambda container image
├── src/shopify_engine/
│   ├── config.py                    # Settings from .env
│   ├── shopify/                       # GraphQL client, bulk ops, queries, webhook registration
│   ├── snowflake/                      # connection, stage/MERGE loader
│   ├── extractors/                      # orders.py, products.py: backfill/incremental extraction
│   ├── sync/                              # watermark state + orchestration (dispatches by --object)
│   ├── webhook/                            # Lambda handler + HMAC verification (orders CDC)
│   └── cli.py
├── scripts/
│   ├── sync_orders.py                # thin entrypoint
│   └── register_webhooks.py            # thin entrypoint
└── tests/
```
