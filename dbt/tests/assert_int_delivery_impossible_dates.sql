{{ config(severity='warn') }}
-- flags impossible data: delivered earlier than purchased; returns anomalous rows
select order_id, order_purchase_timestamp, order_delivered_customer_date
from {{ ref('int_order_delivery_metrics') }}
where order_delivered_customer_date is not null
  and order_purchase_timestamp is not null
  and order_delivered_customer_date < order_purchase_timestamp
