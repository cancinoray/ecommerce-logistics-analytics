-- per (seller_id, time_period) sums must reconcile exactly against stg_order_items line items
-- bucketed by the order's purchase month; returns mismatched rows
with expected as (
    select
        i.seller_id as seller_id,
        dateTrunc('month', d.order_purchase_timestamp) as time_period,
        sum(i.price) as exp_price,
        sum(i.freight_value) as exp_freight,
        countDistinct(i.order_id) as exp_orders
    from {{ ref('stg_order_items') }} as i
    inner join {{ ref('int_order_delivery_metrics') }} as d on i.order_id = d.order_id
    where i.seller_id is not null
        and d.order_purchase_timestamp is not null
    group by seller_id, time_period
),
actual as (
    select
        seller_id,
        time_period,
        total_price,
        total_freight_value,
        order_volume
    from {{ ref('int_seller_freight_metrics') }}
)
select
    e.seller_id,
    e.time_period,
    e.exp_price,
    a.total_price,
    e.exp_freight,
    a.total_freight_value,
    e.exp_orders,
    a.order_volume
from expected as e
full outer join actual as a using (seller_id, time_period)
where a.seller_id is null
    or e.seller_id is null
    or a.total_price != e.exp_price
    or a.total_freight_value != e.exp_freight
    or a.order_volume != e.exp_orders
