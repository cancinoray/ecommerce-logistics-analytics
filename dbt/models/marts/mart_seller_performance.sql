-- grain: one row per (seller_id, time_period)
-- full-refresh: static Olist extract, no incremental logic needed, consistent with all upstream inputs
-- time_period = month start: dateTrunc('month', order_purchase_timestamp) from int_order_delivery_metrics.
-- Month is the coarsest grain supporting plan.md MoM/YoY; day/week can be added later.
-- An order with items from multiple sellers counts once per seller (full order outcome
-- attributed to each seller). on_time_rate excludes 'Delivery data unavailable' from
-- num and denom. avg_review_score over non-null review_score only. order_volume =
-- distinct orders the seller had >=1 item in, within the period.

with order_sellers as (
    select distinct order_id, seller_id
    from {{ ref('stg_order_items') }}
),

delivery as (
    select order_id, order_purchase_timestamp, severity
    from {{ ref('int_order_delivery_metrics') }}
),

experience as (
    select order_id, review_score
    from {{ ref('int_customer_experience_metrics') }}
),

base as (
    select
        s.seller_id as seller_id,
        dateTrunc('month', d.order_purchase_timestamp) as time_period,
        s.order_id as order_id,
        d.severity as severity,
        e.review_score as review_score
    from order_sellers as s
    inner join delivery as d on s.order_id = d.order_id
    left join experience as e on s.order_id = e.order_id
    where d.order_purchase_timestamp is not null
),

agg as (
    select
        seller_id,
        time_period,
        countDistinct(order_id) as order_volume,
        countIf(order_id, severity = 'On Time')
            / nullIf(countIf(order_id, severity != 'Delivery data unavailable'), 0) as on_time_rate,
        avg(review_score) as avg_review_score
    from base
    group by seller_id, time_period
)

select
    a.seller_id as seller_id,
    a.time_period as time_period,
    a.order_volume as order_volume,
    a.on_time_rate as on_time_rate,
    a.avg_review_score as avg_review_score,
    s.seller_city as seller_city,
    s.seller_state as seller_state
from agg as a
inner join {{ ref('dim_seller') }} as s on a.seller_id = s.seller_id
