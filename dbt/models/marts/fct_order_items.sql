-- grain: one row per (order_id, order_item_id)
-- full-refresh: static Olist extract, no incremental logic needed, consistent with all upstream inputs

with items as (
    select * from {{ ref('stg_order_items') }}
)

select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
from items
