#!/usr/bin/env bash
set -euo pipefail

# ECS injects these directly from Secrets Manager as env vars (see
# aws-infrastructure/modules/ecs_service) — SNOWFLAKE_PRIVATE_KEY_PATH (used
# by shopify_engine.config.Settings) expects a file, not raw PEM content, so
# write each one out once at container start. Mirrors
# ingestion/src/shopify_engine/webhook/handler.py's _bootstrap(), just as a
# shell entrypoint instead of a Lambda cold start.
if [ -n "${SNOWFLAKE_PIPELINE_PRIVATE_KEY_PEM:-}" ]; then
  printf '%s' "$SNOWFLAKE_PIPELINE_PRIVATE_KEY_PEM" >/opt/airflow/secrets/pipeline_key.p8
  chmod 600 /opt/airflow/secrets/pipeline_key.p8
fi

if [ -n "${SNOWFLAKE_DBT_PRIVATE_KEY_PEM:-}" ]; then
  printf '%s' "$SNOWFLAKE_DBT_PRIVATE_KEY_PEM" >/opt/airflow/secrets/dbt_key.p8
  chmod 600 /opt/airflow/secrets/dbt_key.p8
fi

exec /entrypoint "$@"
