{{
    config(
        unique_key='product_id',
        incremental_strategy='merge'
    )
}}

with source as (
    select * from {{ ref('stg_shopify__products_json') }}

    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),

renamed as (
    select
        payload:id::string           as product_id,
        payload:title::string        as title,
        payload:handle::string       as handle,
        payload:vendor::string       as vendor,
        payload:productType::string  as product_type,
        payload:status::string       as status,
        payload:createdAt::timestamp_ntz as created_at,
        payload:updatedAt::timestamp_ntz as updated_at,
        payload:tags::array          as tags,
        _loaded_at,
        _source_file
    from source
)

select * from renamed
