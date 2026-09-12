-- grain: one row per seller_id
-- full-refresh: all-time seller snapshot over small data volumes; no incremental logic needed
-- Multi-seller approximation: some orders contain items from multiple sellers.
-- This model attributes the entire order's delivery outcome and review score
-- to every seller who had an item in that order (no fractional allocation).

with seller_orders as (
    select distinct
        seller_id,
        order_id
    from {{ ref('stg_order_items') }}
    where seller_id is not null
),

joined as (
    select
        so.seller_id as seller_id,
        so.order_id as seller_order_id,
        d.severity as severity,
        cx.review_score as review_score
    from seller_orders as so
    left join {{ ref('int_order_delivery_metrics') }} as d
        on so.order_id = d.order_id
    left join {{ ref('int_customer_experience_metrics') }} as cx
        on so.order_id = cx.order_id
)

select
    seller_id,
    countDistinct(seller_order_id) as order_volume,
    countIf(severity = 'On Time') / nullIf(countIf(severity != 'Delivery data unavailable'), 0) as on_time_rate,
    avg(review_score) as avg_review_score
from joined
group by seller_id
