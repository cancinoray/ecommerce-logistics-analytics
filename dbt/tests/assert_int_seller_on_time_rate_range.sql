-- on_time_rate must be between 0 and 1 inclusive; returns offending rows
select seller_id, on_time_rate
from {{ ref('int_seller_performance_metrics') }}
where on_time_rate is not null and (on_time_rate < 0 or on_time_rate > 1)
