-- freight_ratio must be >= 0 where not null (zero-price orders yield NULL and are excluded); returns violating rows
select order_id, freight_ratio
from {{ ref('int_order_freight_metrics') }}
where freight_ratio is not null
    and freight_ratio < 0
