-- grain: one row per customer_unique_id (real person)
-- full-refresh: small dimension (~96k persons), fully rebuilt each run — cheap, no append-only benefit, so no incremental logic
-- address rule: a person may have multiple addresses across orders; winning address is the mode
--   (most frequent zip/city/state combo) within stg_customers; deterministic tie-break is lowest customer_id alphabetically

with ranked as (
    select
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state,
        min(customer_id) as tiebreak_customer_id,
        count(*) as n_rows
    from {{ ref('stg_customers') }}
    group by
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
),

picked as (
    select
        *,
        row_number() over (
            partition by customer_unique_id
            order by n_rows desc, tiebreak_customer_id asc
        ) as rn
    from ranked
)

select
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
from picked
where rn = 1
