from __future__ import annotations

import pendulum
from airflow import DAG
from airflow.operators.bash import BashOperator

# Each service keeps its own least-privilege Snowflake credential (see
# terraform/environments/production/access.yml) — the incremental poll runs
# as SHOPIFY_LOADER_ROLE/SHOPIFY_PIPELINE_SVC against RAW, dbt runs as
# DBT_TRANSFORM_ROLE/DBT_TRANSFORM_SVC against STAGING/SNAPSHOTS. The
# container's entrypoint writes each service's private key to its own file
# (see ../entrypoint.sh) from a Secrets Manager-injected env var.
PIPELINE_ENV = {
    "SNOWFLAKE_USER": "SHOPIFY_PIPELINE_SVC",
    "SNOWFLAKE_ROLE": "SHOPIFY_LOADER_ROLE",
    "SNOWFLAKE_SCHEMA": "RAW",
    "SNOWFLAKE_PRIVATE_KEY_PATH": "/opt/airflow/secrets/pipeline_key.p8",
}

DBT_ENV = {
    "SNOWFLAKE_USER": "DBT_TRANSFORM_SVC",
    "SNOWFLAKE_ROLE": "DBT_TRANSFORM_ROLE",
    "SNOWFLAKE_SCHEMA": "STAGING",
    "SNOWFLAKE_PRIVATE_KEY_PATH": "/opt/airflow/secrets/dbt_key.p8",
}

with DAG(
    dag_id="shopify_sync",
    description="Incremental Shopify sync (reconciliation net for the webhooks) -> dbt run -> dbt snapshot",
    # Webhooks are the primary, near-real-time path into RAW; this DAG exists
    # to catch anything they missed and to keep STAGING/SNAPSHOTS current.
    # Adjust the cadence to how often status actually needs to be fresh.
    schedule="0 * * * *",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    tags=["shopify"],
) as dag:
    sync_orders = BashOperator(
        task_id="sync_orders_incremental",
        bash_command="sync-orders --mode incremental",
        env=PIPELINE_ENV,
        append_env=True,
    )

    sync_products = BashOperator(
        task_id="sync_products_incremental",
        bash_command="sync-orders --object products --mode incremental",
        env=PIPELINE_ENV,
        append_env=True,
    )

    # +stg_shopify__orders pulls in stg_shopify__orders_json too — the
    # snapshot reads from stg_shopify__orders, so both must be fresh first.
    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command="dbt run --project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt",
        env=DBT_ENV,
        append_env=True,
    )

    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot",
        bash_command="dbt snapshot --project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt",
        env=DBT_ENV,
        append_env=True,
    )

    [sync_orders, sync_products] >> dbt_run >> dbt_snapshot
