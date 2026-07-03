with source as (
    select * from {{ source('shopify', 'orders_json') }}
),

flattened as (
    select
        payload:id::string as order_id,
        li.value           as line_item
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
        line_item:totalDiscountSet:shopMoney:amount::number(18, 2)        as total_discount
    from flattened
)

select * from renamed
