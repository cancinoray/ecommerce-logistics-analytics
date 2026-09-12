-- one row per (order_id, order_item_id)
-- full-refresh: static Olist extract, no incremental logic needed, consistent with all upstream inputs

with items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select order_id from {{ ref('fct_orders') }}
),

products as (
    select product_id from {{ ref('dim_product') }}
),

sellers as (
    select seller_id from {{ ref('dim_seller') }}
)

select
    i.order_id as order_id,
    i.order_item_id as order_item_id,
    i.product_id as product_id,
    i.seller_id as seller_id,
    i.shipping_limit_date as shipping_limit_date,
    i.price as price,
    i.freight_value as freight_value
from items as i
left join orders as o on i.order_id = o.order_id
left join products as p on i.product_id = p.product_id
left join sellers as s on i.seller_id = s.seller_id
