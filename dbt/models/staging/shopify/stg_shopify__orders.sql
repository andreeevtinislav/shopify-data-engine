with source as (
    select * from {{ source('shopify', 'orders_json') }}
),

renamed as (
    select
        payload:id::string                                           as order_id,
        payload:name::string                                         as order_name,
        payload:createdAt::timestamp_ntz                              as created_at,
        payload:updatedAt::timestamp_ntz                              as updated_at,
        payload:cancelledAt::timestamp_ntz                            as cancelled_at,
        payload:closedAt::timestamp_ntz                               as closed_at,
        payload:displayFinancialStatus::string                       as financial_status,
        payload:displayFulfillmentStatus::string                     as fulfillment_status,
        payload:currentTotalPriceSet:shopMoney:amount::number(18, 2)  as current_total_price,
        payload:currentTotalPriceSet:shopMoney:currencyCode::string   as currency_code,
        payload:subtotalPriceSet:shopMoney:amount::number(18, 2)      as subtotal_price,
        payload:totalDiscountsSet:shopMoney:amount::number(18, 2)     as total_discounts,
        payload:totalTaxSet:shopMoney:amount::number(18, 2)           as total_tax,
        _loaded_at,
        _source_file
    from source
)

select * from renamed
