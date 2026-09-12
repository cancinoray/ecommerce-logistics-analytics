-- grain: one row per order

with source as (

    select *
    from {{ source('raw', 'orders') }}

)

select
    order_id,
    customer_id,
    lower(trim(order_status)) as order_status,
    toDateTime64OrNull(order_purchase_timestamp, 0) as order_purchase_timestamp,
    toDateTime64OrNull(order_approved_at, 0) as order_approved_at,
    toDateTime64OrNull(order_delivered_carrier_date, 0) as order_delivered_carrier_date,
    toDateTime64OrNull(order_delivered_customer_date, 0) as order_delivered_customer_date,
    toDateTime64OrNull(order_estimated_delivery_date, 0) as order_estimated_delivery_date
from source
