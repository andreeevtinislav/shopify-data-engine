{{
    config(
        unique_key='variant_id',
        incremental_strategy='merge'
    )
}}

-- Same fan-out caveat as stg_shopify__order_line_items: a MERGE only upserts
-- variants still present on the product's latest payload — it can't detect a
-- variant deleted from a product between syncs (no tombstone in RAW to delete
-- against). Revisit with a delete+insert-per-product strategy if variant
-- deletion turns out to matter in practice.
with source as (
    select * from {{ ref('stg_shopify__products_json') }}

    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),

flattened as (
    select
        payload:id::string as product_id,
        v.value            as variant,
        _loaded_at
    from source,
    lateral flatten(input => payload:variants) as v
),

renamed as (
    select
        product_id,
        variant:id::string                    as variant_id,
        variant:title::string                 as title,
        variant:sku::string                   as sku,
        variant:price::number(18, 2)          as price,
        variant:compareAtPrice::number(18, 2) as compare_at_price,
        variant:inventoryQuantity::number     as inventory_quantity,
        variant:position::number              as position,
        _loaded_at
    from flattened
)

select * from renamed
