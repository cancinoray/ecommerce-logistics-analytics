-- row count in int must equal row count in stg_orders (no fan-out); returns a row on mismatch
select
    (select count(*) from {{ ref('int_order_delivery_metrics') }}) as int_cnt,
    (select count(*) from {{ ref('stg_orders') }}) as stg_cnt
where int_cnt != stg_cnt
