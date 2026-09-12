-- grain: one row per (order_id, payment_sequential)

-- No deduplication: an order can legitimately have multiple payment rows
-- (split payments / installments) by design, so every raw row is preserved.

with source as (

    select *
    from {{ source('raw', 'order_payments') }}

)

select
    order_id,
    toUInt8OrNull(trim(payment_sequential)) as payment_sequential,
    lower(trim(payment_type)) as payment_type,
    toUInt8OrNull(trim(payment_installments)) as payment_installments,
    toFloat64OrNull(trim(payment_value)) as payment_value
from source
