-- grain: one row per order_id (deliberate exception to the normal staging 1:1-with-source convention: raw order_reviews can hold multiple rows per order_id, collapsed here to the most recent review)
-- full-refresh: no incremental logic needed at staging grain for this source

with source as (

    select *
    from {{ source('raw', 'order_reviews') }}

),

cleaned as (

    select
        order_id,
        review_id,
        toUInt8OrNull(trim(review_score)) as review_score,
        lower(trim(review_comment_title)) as review_comment_title,
        lower(trim(review_comment_message)) as review_comment_message,
        toDateTime64OrNull(review_creation_date, 0) as review_creation_date,
        toDateTime64OrNull(review_answer_timestamp, 0) as review_answer_timestamp
    from source

),

ranked as (

    select
        *,
        -- tie-break: identical review_creation_date on the same order is resolved
        -- deterministically by later review_answer_timestamp, then lowest review_id,
        -- so re-runs produce identical results every time
        row_number() over (
            partition by order_id
            order by review_creation_date desc nulls last, review_answer_timestamp desc nulls last, review_id asc
        ) as _rn
    from cleaned

)

select
    order_id,
    review_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
from ranked
where _rn = 1
