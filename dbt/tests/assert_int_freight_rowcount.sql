-- row count must equal distinct order_id count in stg_order_items (pure rollup, no filtering); returns a row on mismatch
select
    (select count(*) from {{ ref('int_order_freight_metrics') }}) as int_cnt,
    (select count(distinct order_id) from {{ ref('stg_order_items') }}) as stg_cnt
where int_cnt != stg_cnt
