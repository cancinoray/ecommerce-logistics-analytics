-- grain: one row per order_id
-- full-refresh: static Olist extract, no incremental logic needed, consistent with all upstream inputs

with orders as (
    select * from {{ ref('stg_orders') }}
),

customer_lookup as (
    select customer_id, customer_unique_id from {{ ref('stg_customers') }}
),

delivery as (
    select order_id, delay_days, severity from {{ ref('int_order_delivery_metrics') }}
),

freight as (
    select order_id, total_price, total_freight_value, freight_ratio from {{ ref('int_order_freight_metrics') }}
),

experience as (
    select order_id, review_score from {{ ref('int_customer_experience_metrics') }}
)

select
    o.order_id as order_id,
    o.customer_id as customer_id,
    cl.customer_unique_id as customer_unique_id,
    o.order_status as order_status,
    o.order_purchase_timestamp as order_purchase_timestamp,
    o.order_approved_at as order_approved_at,
    o.order_delivered_carrier_date as order_delivered_carrier_date,
    o.order_delivered_customer_date as order_delivered_customer_date,
    o.order_estimated_delivery_date as order_estimated_delivery_date,
    delivery.delay_days as delay_days,
    delivery.severity as delivery_severity,
    freight.total_price as total_price,
    freight.total_freight_value as total_freight_value,
    freight.freight_ratio as freight_ratio,
    experience.review_score as review_score
from orders as o
left join customer_lookup as cl on o.customer_id = cl.customer_id
left join delivery on o.order_id = delivery.order_id
left join freight on o.order_id = freight.order_id
left join experience on o.order_id = experience.order_id
left join {{ ref('dim_customer') }} as dc on cl.customer_unique_id = dc.customer_unique_id
