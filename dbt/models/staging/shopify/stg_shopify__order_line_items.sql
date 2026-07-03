{{
    config(
        unique_key='line_item_id',
        incremental_strategy='merge'
    )
}}

-- Caveat: this fans out from one order into N line items via LATERAL FLATTEN,
-- so a MERGE only upserts line items still present on the order's latest
-- payload — it can't detect a line item that was removed from an order
-- between syncs (there's no tombstone in RAW to delete against). Acceptable
-- for v1 since Shopify orders essentially never drop line items post-creation
-- (refunds/cancellations are separate objects, not payload mutations); revisit
-- with a delete+insert-per-order strategy if that assumption stops holding.
with source as (
    select * from {{ ref('stg_shopify__orders_json') }}

    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),

flattened as (
    select
        payload:id::string as order_id,
        li.value           as line_item,
        _loaded_at
    from source,
    lateral flatten(input => payload:lineItems) as li
),

renamed as (
    select
        order_id,
        line_item:id::string                                             as line_item_id,
        line_item:title::string                                          as title,
        line_item:quantity::number                                       as quantity,
        line_item:sku::string                                            as sku,
        line_item:originalUnitPriceSet:shopMoney:amount::number(18, 2)    as original_unit_price,
        line_item:totalDiscountSet:shopMoney:amount::number(18, 2)        as total_discount,
        _loaded_at
    from flattened
)

select * from renamed
