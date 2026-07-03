{{
    config(
        unique_key='refund_id',
        incremental_strategy='merge'
    )
}}

-- Same fan-out caveat as stg_shopify__order_line_items: refunds can only be
-- added to an order in Shopify, never removed, so MERGE-without-delete is safe
-- here in practice (unlike a hypothetical editable child collection).
with source as (
    select * from {{ ref('stg_shopify__orders_json') }}

    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),

flattened as (
    select
        payload:id::string as order_id,
        rf.value           as refund,
        _loaded_at
    from source,
    lateral flatten(input => payload:refunds) as rf
),

renamed as (
    select
        order_id,
        refund:id::string                                           as refund_id,
        refund:createdAt::timestamp_ntz                              as refunded_at,
        refund:totalRefundedSet:shopMoney:amount::number(18, 2)      as total_refunded,
        _loaded_at
    from flattened
)

select * from renamed
