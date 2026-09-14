-- mart_seller_freight must carry exactly the same (seller_id, time_period) grain as
-- mart_seller_performance (acceptance criterion: identical row set, 16,441 rows in the
-- current Olist extract). Returns one row per disagreement; 0 rows = PASS.
with freight as (
    select
        seller_id,
        time_period,
        toNullable(1) as in_freight
    from {{ ref('mart_seller_freight') }}
),
performance as (
    select
        seller_id,
        time_period,
        toNullable(1) as in_perf
    from {{ ref('mart_seller_performance') }}
)
select
    seller_id,
    time_period,
    in_freight,
    in_perf
from freight as f
full outer join performance using (seller_id, time_period)
where in_freight is null
    or in_perf is null
