-- grain: one row per order_month
-- full-refresh: aggregates full order history each run to keep percentages
-- internally consistent as late-arriving delivery/review updates arrive;
-- volume does not warrant incremental complexity

select
    dateTrunc('month', order_purchase_timestamp) as order_month,
    count(*) as order_count,
    countIf(delivery_severity = 'Delivery data unavailable')
        / nullIf(countIf(delivery_severity != 'Canceled or unavailable'), 0) as pct_orders_unavailable_delivery_data,
    countIf(delivery_severity = 'Canceled or unavailable') / count(*) as pct_orders_canceled_or_unavailable,
    countIf(review_score is null) / count(*) as pct_orders_missing_review,
    countIf(
        order_delivered_customer_date is not null
        and order_delivered_customer_date < order_purchase_timestamp
    ) / count(*) as pct_orders_impossible_date_ordering
from {{ ref('int_customer_experience_metrics') }}
group by 1
having count(*) >= 1
