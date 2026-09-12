-- grain: one row per customer_id
-- full-refresh: staging pass-through over source, 1:1 with raw.customers, no incremental logic

with source as (

    select *
    from {{ source('raw', 'customers') }}

)

select
    customer_id,
    customer_unique_id,
    toString(customer_zip_code_prefix) as customer_zip_code_prefix,
    lower(trim(customer_city)) as customer_city,
    lower(trim(customer_state)) as customer_state
from source
