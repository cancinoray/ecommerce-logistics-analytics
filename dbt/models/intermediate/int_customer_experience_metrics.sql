-- grain: one row per order_id
-- full-refresh: matches upstream stg_order_reviews and int_order_delivery_metrics; volume does not warrant incremental complexity

select
    d.order_id,
    d.order_purchase_timestamp,
    d.order_delivered_customer_date,
    d.order_estimated_delivery_date,
    d.delay_days,
    d.severity as delivery_severity,
    r.review_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp
from {{ ref('int_order_delivery_metrics') }} as d
left join {{ ref('stg_order_reviews') }} as r
    on d.order_id = r.order_id
