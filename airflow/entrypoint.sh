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

# `airflow standalone` auto-creates an admin user with a random password on
# first boot IF none exists yet — fine for a laptop demo, useless here since
# the metadata DB lives on local/ephemeral task storage (see
# aws-infrastructure's ecs_services.tf comment) and gets recreated from
# scratch on every restart, so the "random" password would change every time
# too. Pre-creating a fixed-credential user before handing off to `standalone`
# makes it a no-op there (it only generates one when no user exists).
if [ -n "${AIRFLOW_ADMIN_PASSWORD:-}" ]; then
  airflow db migrate
  airflow users create \
    --username "${AIRFLOW_ADMIN_USERNAME:-admin}" \
    --password "$AIRFLOW_ADMIN_PASSWORD" \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com \
    || true # already exists if this is a warm restart of the same DB (local storage may have survived), that's fine
fi

exec /entrypoint "$@"
