-- grain: one row per seller_id
-- full-refresh: staging pass-through over source, 1:1 with raw.sellers, no incremental logic

with source as (

    select *
    from {{ source('raw', 'sellers') }}

)

select
    seller_id,
    toString(seller_zip_code_prefix) as seller_zip_code_prefix,
    lower(trim(seller_city)) as seller_city,
    lower(trim(seller_state)) as seller_state
from source
