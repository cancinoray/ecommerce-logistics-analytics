-- reconciliation: every distinct order-related date (cast to Date) in stg_orders
-- must exist in dim_date.date_day; a gap would silently orphan MoM/YoY joins in fct_orders/fct_order_items.
-- This test fails if any stg_orders timestamp's date falls outside the dim_date spine range.
-- Returns orphan dates.

with all_order_dates as (
    select distinct toDate(order_purchase_timestamp) as order_date
    from {{ ref('stg_orders') }}
    where order_purchase_timestamp is not null
    union distinct
    select distinct toDate(order_approved_at) as order_date
    from {{ ref('stg_orders') }}
    where order_approved_at is not null
    union distinct
    select distinct toDate(order_delivered_carrier_date) as order_date
    from {{ ref('stg_orders') }}
    where order_delivered_carrier_date is not null
    union distinct
    select distinct toDate(order_delivered_customer_date) as order_date
    from {{ ref('stg_orders') }}
    where order_delivered_customer_date is not null
    union distinct
    select distinct toDate(order_estimated_delivery_date) as order_date
    from {{ ref('stg_orders') }}
    where order_estimated_delivery_date is not null
)

select
    a.order_date as missing_date
from all_order_dates as a
left join {{ ref('dim_date') }} as d
    on d.date_day = a.order_date
where d.date_day is null
