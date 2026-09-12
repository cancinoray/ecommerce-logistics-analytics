-- grain: one row per order_month
-- full-refresh: thin marts passthrough of int_data_quality_flags (#19); no
-- incremental logic, matching upstream refresh strategy

select
    order_month,
    pct_orders_unavailable_delivery_data,
    pct_orders_missing_review,
    pct_orders_impossible_date_ordering
from {{ ref('int_data_quality_flags') }}
