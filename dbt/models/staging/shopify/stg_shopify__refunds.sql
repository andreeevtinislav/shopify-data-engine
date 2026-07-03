with source as (
    select * from {{ source('shopify', 'orders_json') }}
),

flattened as (
    select
        payload:id::string as order_id,
        rf.value           as refund
    from source,
    lateral flatten(input => payload:refunds) as rf
),

renamed as (
    select
        order_id,
        refund:id::string                                           as refund_id,
        refund:createdAt::timestamp_ntz                              as refunded_at,
        refund:totalRefundedSet:shopMoney:amount::number(18, 2)      as total_refunded
    from flattened
)

select * from renamed
