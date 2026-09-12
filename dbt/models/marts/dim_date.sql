-- grain: one row per calendar date
-- full-refresh: small deterministic spine (~984 rows for 2016-06-04 to 2019-02-12); fully rebuilt each run — no append-only source, so incremental adds complexity with no benefit
-- week_of_year uses ISO 8601 via toISOWeek() (weeks Monday-Sunday, week 1 is the week containing the year's first Thursday)

with spine as (
    select addDays(toDate('2016-06-04'), number) as date_day
    from system.numbers
    where number <= dateDiff('day', toDate('2016-06-04'), toDate('2019-02-12'))
)

select
    date_day,
    toYear(date_day) as year,
    toQuarter(date_day) as quarter,
    toMonth(date_day) as month,
    case toMonth(date_day)
        when 1 then 'January'
        when 2 then 'February'
        when 3 then 'March'
        when 4 then 'April'
        when 5 then 'May'
        when 6 then 'June'
        when 7 then 'July'
        when 8 then 'August'
        when 9 then 'September'
        when 10 then 'October'
        when 11 then 'November'
        else 'December'
    end as month_name,
    toISOWeek(date_day) as week_of_year,
    toDayOfWeek(date_day) as day_of_week,
    if(toDayOfWeek(date_day) >= 6, 1, 0) as is_weekend
from spine
order by date_day
