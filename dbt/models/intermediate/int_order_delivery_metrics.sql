-- grain: one row per order_id

select
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    case
        when order_status in ('canceled', 'unavailable') then null
        when order_delivered_customer_date is null or order_estimated_delivery_date is null then null
        else dateDiff('day', order_estimated_delivery_date, order_delivered_customer_date)
    end as delay_days,
    case
        when order_status in ('canceled', 'unavailable') then 'Canceled or unavailable'
        when order_delivered_customer_date is null or order_estimated_delivery_date is null then 'Delivery data unavailable'
        when dateDiff('day', order_estimated_delivery_date, order_delivered_customer_date) <= 0 then 'On Time'
        when dateDiff('day', order_estimated_delivery_date, order_delivered_customer_date) between 1 and 3 then '1-3 days late'
        when dateDiff('day', order_estimated_delivery_date, order_delivered_customer_date) between 4 and 7 then '4-7 days late'
        else '8+ days late'
    end as severity
from {{ ref('stg_orders') }}
