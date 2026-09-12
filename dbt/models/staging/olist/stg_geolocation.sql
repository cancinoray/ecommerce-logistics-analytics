-- grain: one row per zip_code_prefix — deliberately deviates from 1:1-with-source staging convention, see #9 for the other exception
-- full-refresh: small reference table, no incremental logic needed

with source as (

    select *
    from {{ source('raw', 'geolocation') }}

),

filtered as (

    select
        toString(geolocation_zip_code_prefix) as zip_code_prefix,
        toFloat64OrNull(trim(geolocation_lat)) as lat,
        toFloat64OrNull(trim(geolocation_lng)) as lng,
        lower(trim(geolocation_city)) as city,
        lower(trim(geolocation_state)) as state
    from source
    where geolocation_zip_code_prefix is not null
      and trim(toString(geolocation_zip_code_prefix)) != ''

),

coords as (

    select
        zip_code_prefix,
        -- known limitation: unweighted mean (avg) per prefix; outlier/erroneous
        -- coordinates are not filtered or clustered (explicitly out of scope for #14)
        avg(lat) as lat,
        avg(lng) as lng
    from filtered
    group by zip_code_prefix

),

city_ranked as (

    select
        zip_code_prefix,
        city,
        state,
        row_number() over (
            partition by zip_code_prefix
            -- rule: most frequent (city, state) pair per prefix; ties broken by
            -- lexicographically first city, so output is deterministic across runs
            order by count(*) desc, city asc
        ) as _rn
    from filtered
    group by zip_code_prefix, city, state

),

top_city as (

    select zip_code_prefix, city, state
    from city_ranked
    where _rn = 1

)

select
    c.zip_code_prefix,
    c.lat,
    c.lng,
    t.city,
    t.state
from coords as c
inner join top_city as t using (zip_code_prefix)
