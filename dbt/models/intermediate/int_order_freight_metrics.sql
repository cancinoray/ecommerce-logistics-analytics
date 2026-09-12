-- grain: one row per order_id (grain-changing rollup from line-item grain)
-- full-refresh: static Olist extract, no incremental logic needed; reads only stg_order_items

select
    order_id,
    sum(price) as total_price,
    sum(freight_value) as total_freight_value,
    case
        when sum(price) = 0 then null
        else sum(freight_value) / sum(price)
    end as freight_ratio
from {{ ref('stg_order_items') }}
group by order_id
