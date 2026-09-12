-- order_volume must be > 0 for every seller; returns offending rows
select seller_id, order_volume
from {{ ref('int_seller_performance_metrics') }}
where order_volume <= 0 or order_volume is null
