-- grain: one row per (order_id, order_item_id)

with source as (

    select *
    from {{ source('raw', 'order_items') }}

)

select
    order_id,
    toUInt8OrNull(trim(order_item_id)) as order_item_id,
    product_id,
    seller_id,
    toDateTime64OrNull(trim(shipping_limit_date), 0) as shipping_limit_date,
    toFloat64OrNull(trim(price)) as price,
    toFloat64OrNull(trim(freight_value)) as freight_value
from source
