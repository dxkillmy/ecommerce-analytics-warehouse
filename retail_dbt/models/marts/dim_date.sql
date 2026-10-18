with bounds as (
    select
        min(invoice_date)::date as d_min,
        max(invoice_date)::date as d_max
    from {{ source('staging', 'online_retail') }}
)

select
    d::date                                  as date_day,
    extract(year from d)::int                as year_num,
    extract(quarter from d)::int             as quarter_num,
    extract(month from d)::int               as month_num,
    to_char(d, 'Mon')                        as month_name,
    extract(isodow from d)::int              as day_of_week,
    to_char(d, 'Dy')                         as day_name,
    extract(isodow from d) in (6, 7)         as is_weekend
from bounds,
     generate_series(d_min, d_max, interval '1 day') as d