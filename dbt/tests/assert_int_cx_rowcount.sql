-- row count must equal int_order_delivery_metrics exactly (left join preserves every row); returns a row on mismatch
select
    (select count(*) from {{ ref('int_customer_experience_metrics') }}) as int_cnt,
    (select count(*) from {{ ref('int_order_delivery_metrics') }}) as delivery_cnt
where int_cnt != delivery_cnt
