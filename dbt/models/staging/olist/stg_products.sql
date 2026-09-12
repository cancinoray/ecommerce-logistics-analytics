-- grain: one row per product_id
-- full-refresh: small dimension-style table, 1:1 with raw.products, no incremental logic
-- intentional exception: staging model referencing another staging model (stg_product_category_translation) for English category names

with source as (

    select *
    from {{ source('raw', 'products') }}

),

translation as (

    select *
    from {{ ref('stg_product_category_translation') }}

)

select
    source.product_id,
    source.product_category_name,
    translation.product_category_name_english,
    toUInt32OrNull(trim(source.product_name_lenght)) as product_name_lenght,
    toUInt32OrNull(trim(source.product_description_lenght)) as product_description_lenght,
    toUInt32OrNull(trim(source.product_photos_qty)) as product_photos_qty,
    toFloat64OrNull(trim(source.product_weight_g)) as product_weight_g,
    toFloat64OrNull(trim(source.product_length_cm)) as product_length_cm,
    toFloat64OrNull(trim(source.product_height_cm)) as product_height_cm,
    toFloat64OrNull(trim(source.product_width_cm)) as product_width_cm
from source
left join translation
    on source.product_category_name = translation.product_category_name
