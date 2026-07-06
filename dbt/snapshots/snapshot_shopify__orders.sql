{% snapshot snapshot_shopify__orders %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='order_id',
        strategy='check',
        check_cols=['financial_status', 'fulfillment_status', 'cancelled_at'],
    )
}}

-- SCD Type 2 history of order status. dbt inserts a new row (with
-- dbt_valid_from/dbt_valid_to bounding each version) only when one of
-- check_cols actually changes between snapshot runs — not on every touch of
-- the order (unrelated field edits don't create noise). financial_status
-- moving to PARTIALLY_REFUNDED/REFUNDED is how a return shows up here;
-- individual refund events themselves are already an append-only log in
-- stg_shopify__refunds and don't need their own snapshot.
--
-- Requires a `dbt snapshot` run on some schedule (not part of `dbt run`/`dbt
-- build`) to actually capture history — see ../README.md.
select
    order_id,
    order_name,
    financial_status,
    fulfillment_status,
    cancelled_at,
    closed_at,
    updated_at
from {{ ref('stg_shopify__orders') }}

{% endsnapshot %}
