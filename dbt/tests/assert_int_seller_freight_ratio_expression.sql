-- freight_ratio must equal total_freight_value / total_price when total_price != 0,
-- and must be NULL when total_price = 0 (same rule as #16); returns violating rows
select
    seller_id,
    time_period,
    total_price,
    total_freight_value,
    freight_ratio
from {{ ref('int_seller_freight_metrics') }}
where (total_price = 0 and freight_ratio is not null)
    or (
        total_price != 0
        and (freight_ratio is null or abs(freight_ratio - total_freight_value / total_price) > 1e-9)
    )
