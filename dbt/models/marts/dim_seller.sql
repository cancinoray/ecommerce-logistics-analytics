-- grain: one row per seller_id
-- full-refresh: small dimension, 1:1 passthrough of stg_sellers, fully rebuilt each run

select
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
from {{ ref('stg_sellers') }}
