-- grain: one row per product_id
-- full-refresh: small dimension, 1:1 passthrough of stg_products, fully rebuilt each run
-- nulls carried as-is: product_category_name_english may be null (untranslated);
-- weight/dimension fields may be null or 0 (source DQ issue) — no coalesce, no filtering

select
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
from {{ ref('stg_products') }}
