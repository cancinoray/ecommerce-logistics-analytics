-- grain: one row per order_month
-- full-refresh: static Olist extract, no incremental logic needed, consistent with all upstream inputs
-- Logistics Performance Score: composite 0-100, one row per calendar month (order_month = month start).
-- Components (independently normalized 0-100): Delivery 40%, Customer Experience 30%,
-- Logistics Cost 20%, Seller Performance 10%.
-- Data quality is excluded from this score (plan.md s14); this model never references
-- int_data_quality_flags or mart_data_quality.
-- Worked re-weighting example: if Logistics Cost (20%) is not computable for a month,
-- remaining weights Delivery 40% + CX 30% + Seller 10% = 80%. Rescale by /0.8:
-- Delivery 50%, CX 37.5%, Seller 12.5% (sum 100%); final = weighted avg over those three.
-- A naive 0.4*D + 0.3*C + 0.2*0 + 0.1*S is incorrect and must be rejected in review.

with orders as (
    select
        order_id,
        dateTrunc('month', order_purchase_timestamp) as order_month,
        delivery_severity,
        review_score,
        freight_ratio
    from {{ ref('fct_orders') }}
    where order_purchase_timestamp is not null
),

delivery as (
    select
        order_month,
        avg(
            case delivery_severity
                when 'On Time' then 100.0
                when '1-3 days late' then 70.0
                when '4-7 days late' then 35.0
                when '8+ days late' then 0.0
            end
        ) as delivery_score
    from orders
    where delivery_severity != 'Delivery data unavailable'
        and delivery_severity is not null
    group by order_month
),

customer_experience as (
    select
        order_month,
        (avg(review_score) - 1) / 4 * 100 as customer_experience_score
    from orders
    where review_score is not null
    group by order_month
),

global_freight as (
    select
        min(freight_ratio) as global_min_freight_ratio,
        max(freight_ratio) as global_max_freight_ratio
    from orders
    where freight_ratio is not null
),

monthly_freight as (
    select
        order_month,
        avg(freight_ratio) as month_avg_freight_ratio
    from orders
    where freight_ratio is not null
    group by order_month
),

logistics_cost as (
    select
        m.order_month,
        case
            when g.global_max_freight_ratio = g.global_min_freight_ratio then 100.0
            else 100 * (1 - (m.month_avg_freight_ratio - g.global_min_freight_ratio)
                / (g.global_max_freight_ratio - g.global_min_freight_ratio))
        end as logistics_cost_score
    from monthly_freight as m
    cross join global_freight as g
),

order_sellers as (
    -- distinct (order, seller) grain: an order with items from multiple sellers
    -- counts once per seller (full order outcome attributed to each seller,
    -- accepted multi-seller approximation from #18, applied per month)
    select distinct i.order_id, i.seller_id
    from {{ ref('stg_order_items') }} as i
),

seller as (
    select
        o.order_month,
        avg(
            case o.delivery_severity
                when 'On Time' then 100.0
                when '1-3 days late' then 70.0
                when '4-7 days late' then 35.0
                when '8+ days late' then 0.0
            end
        ) as seller_score
    from order_sellers as s
    inner join orders as o on s.order_id = o.order_id
    where o.delivery_severity != 'Delivery data unavailable'
        and o.delivery_severity is not null
    group by o.order_month
),

months as (
    select order_month from delivery
    union distinct
    select order_month from customer_experience
    union distinct
    select order_month from logistics_cost
    union distinct
    select order_month from seller
)

select
    m.order_month as order_month,
    d.delivery_score as delivery_score,
    c.customer_experience_score as customer_experience_score,
    l.logistics_cost_score as logistics_cost_score,
    s.seller_score as seller_score,
    (
        (if(d.delivery_score is null, 0.0, 0.4 * d.delivery_score))
        + (if(c.customer_experience_score is null, 0.0, 0.3 * c.customer_experience_score))
        + (if(l.logistics_cost_score is null, 0.0, 0.2 * l.logistics_cost_score))
        + (if(s.seller_score is null, 0.0, 0.1 * s.seller_score))
    )
    / nullif(
        (if(d.delivery_score is null, 0.0, 0.4))
        + (if(c.customer_experience_score is null, 0.0, 0.3))
        + (if(l.logistics_cost_score is null, 0.0, 0.2))
        + (if(s.seller_score is null, 0.0, 0.1)),
        0
    ) as final_score
from months as m
left join delivery as d on m.order_month = d.order_month
left join customer_experience as c on m.order_month = c.order_month
left join logistics_cost as l on m.order_month = l.order_month
left join seller as s on m.order_month = s.order_month
