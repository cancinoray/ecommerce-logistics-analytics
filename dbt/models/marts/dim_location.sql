-- grain: one row per zip_code_prefix — straight passthrough from stg_geolocation (#14), no grain change or re-aggregation performed here.
-- full-refresh: small reference table, no incremental logic needed

select
    zip_code_prefix,
    city,
    state,
    lat,
    lng
from {{ ref('stg_geolocation') }}
