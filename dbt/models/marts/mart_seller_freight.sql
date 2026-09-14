-- grain: one row per (seller_id, time_period)
-- full-refresh: static Olist extract (16,441 rows), thin passthrough of int_seller_freight_metrics;
-- no incremental logic needed, consistent with mart_seller_performance (#28).
-- seller_city/seller_state are seller-origin geography from dim_seller (#22), distinct from the
-- customer geography already carried on fct_orders.

select
    f.seller_id as seller_id,
    f.time_period as time_period,
    f.order_volume as order_volume,
    f.total_price as total_price,
    f.total_freight_value as total_freight_value,
    f.freight_ratio as freight_ratio,
    s.seller_city as seller_city,
    s.seller_state as seller_state
from {{ ref('int_seller_freight_metrics') }} as f
inner join {{ ref('dim_seller') }} as s on f.seller_id = s.seller_id
