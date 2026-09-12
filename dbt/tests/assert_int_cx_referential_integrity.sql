-- every order_id in this model must exist in int_order_delivery_metrics; returns orphans
select c.order_id
from {{ ref('int_customer_experience_metrics') }} as c
left join {{ ref('int_order_delivery_metrics') }} as d
    on c.order_id = d.order_id
where d.order_id is null
