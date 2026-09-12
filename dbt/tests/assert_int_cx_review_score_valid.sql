-- review_score must be in (1,2,3,4,5) or null (no review given); returns offending rows
select order_id, review_score
from {{ ref('int_customer_experience_metrics') }}
where review_score is not null and review_score not in (1, 2, 3, 4, 5)
