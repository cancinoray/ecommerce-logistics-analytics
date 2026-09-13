-- fct_order_items is a pure passthrough of stg_order_items at one row per (order_id, order_item_id):
-- price and freight_value must be identical, and no grain key may exist on only one side.
-- Returns one row per disagreement (mismatched value or one-sided key); 0 rows = PASS.
-- NULL-safe: NULL vs non-NULL is a mismatch, NULL vs NULL is a match. A plain != cannot be
-- used alone because in ClickHouse it yields NULL for null operands and would silently pass.
with stg as (
    select
        order_id,
        order_item_id,
        price as stg_price,
        freight_value as stg_freight_value,
        toNullable(1) as in_stg
    from {{ ref('stg_order_items') }}
),
fct as (
    select
        order_id,
        order_item_id,
        price as fct_price,
        freight_value as fct_freight_value,
        toNullable(1) as in_fct
    from {{ ref('fct_order_items') }}
)
select
    if(s.in_stg is null, f.order_id, s.order_id) as order_id,
    if(s.in_stg is null, f.order_item_id, s.order_item_id) as order_item_id,
    s.stg_price,
    f.fct_price,
    s.stg_freight_value,
    f.fct_freight_value
from stg s
full outer join fct f
    on s.order_id = f.order_id
    and s.order_item_id = f.order_item_id
where s.in_stg is null  -- grain key present only in fct_order_items
    or f.in_fct is null  -- grain key present only in stg_order_items
    or (s.stg_price is null and f.fct_price is not null)
    or (s.stg_price is not null and f.fct_price is null)
    or (s.stg_price is not null and f.fct_price is not null and s.stg_price != f.fct_price)
    or (s.stg_freight_value is null and f.fct_freight_value is not null)
    or (s.stg_freight_value is not null and f.fct_freight_value is null)
    or (s.stg_freight_value is not null and f.fct_freight_value is not null and s.stg_freight_value != f.fct_freight_value)
