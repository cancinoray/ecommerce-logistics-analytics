-- per-order sums must reconcile exactly against stg_order_items grouped by order_id; returns mismatched rows
with expected as (
    select
        order_id,
        sum(price) as exp_price,
        sum(freight_value) as exp_freight
    from {{ ref('stg_order_items') }}
    group by order_id
),
actual as (
    select
        order_id,
        total_price,
        total_freight_value
    from {{ ref('int_order_freight_metrics') }}
)
select
    e.order_id,
    e.exp_price,
    a.total_price,
    e.exp_freight,
    a.total_freight_value
from expected e
full outer join actual a using (order_id)
where a.order_id is null
    or e.order_id is null
    or a.total_price != e.exp_price
    or a.total_freight_value != e.exp_freight
