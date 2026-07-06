{{
    config(
        unique_key='_shopify_product_id',
        incremental_strategy='merge'
    )
}}

-- Single deduped read of the RAW source: every other model in this folder
-- refs() this instead of hitting source() directly, so there's exactly one
-- place that knows how to pull "what's new" out of RAW.SHOPIFY_PRODUCTS_JSON.
-- Incrementally maintained by _loaded_at, which also tracks product *updates*
-- (RAW is MERGE-upserted by product id, so an edited product gets a fresh
-- _loaded_at and flows through here again on the next run).
select
    _shopify_product_id,
    payload,
    _loaded_at,
    _source_file
from {{ source('shopify', 'products_json') }}

{% if is_incremental() %}
where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
{% endif %}
