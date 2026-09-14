-- grain: one row per (seller_id, time_period)
-- full-refresh: static Olist extract, no incremental logic needed; reads stg_order_items and int_order_delivery_metrics
-- time_period = month start: dateTrunc('month', order_purchase_timestamp) from int_order_delivery_metrics,
-- matching mart_seller_performance (#28) so the two marts join 1:1 on (seller_id, time_period).
-- Multi-seller approximation (same as #18/#28): order_volume counts the distinct orders the seller
-- had >=1 item in and attributes the full order to every seller. total_price and total_freight_value
-- sum the seller's own line items, so they partition cleanly by seller_id with no double count.
-- freight_ratio = total_freight_value / total_price, NULL when total_price = 0 (same rule as #16).
-- Single currency (BRL), no conversion.

with line_items as (
    select
        order_id,
        seller_id,
        price,
        freight_value
    from {{ ref('stg_order_items') }}
    where seller_id is not null
),

delivery as (
    select
        order_id,
        order_purchase_timestamp
    from {{ ref('int_order_delivery_metrics') }}
    where order_purchase_timestamp is not null
),

base as (
    select
        li.seller_id as seller_id,
        dateTrunc('month', d.order_purchase_timestamp) as time_period,
        li.order_id as order_id,
        li.price as price,
        li.freight_value as freight_value
    from line_items as li
    inner join delivery as d on li.order_id = d.order_id
)

select
    seller_id,
    time_period,
    countDistinct(order_id) as order_volume,
    sum(price) as total_price,
    sum(freight_value) as total_freight_value,
    case
        when sum(price) = 0 then null
        else sum(freight_value) / sum(price)
    end as freight_ratio
from base
group by seller_id, time_period
