-- grain: one row per product_category_name (Portuguese)
-- full-refresh: staging pass-through over source, 1:1 with raw.product_category_name_translation, no incremental logic

with source as (

    select *
    from {{ source('raw', 'product_category_name_translation') }}

)

select
    product_category_name,
    product_category_name_english
from source
