-- severity must always match delay_days per the bucket definition; returns violating rows
select order_id, delay_days, severity
from {{ ref('int_order_delivery_metrics') }}
where not (
    (severity = 'Canceled or unavailable' and delay_days is null)
    or (delay_days is null and severity = 'Delivery data unavailable')
    or (delay_days is not null and delay_days <= 0 and severity = 'On Time')
    or (delay_days between 1 and 3 and severity = '1-3 days late')
    or (delay_days between 4 and 7 and severity = '4-7 days late')
    or (delay_days >= 8 and severity = '8+ days late')
)
