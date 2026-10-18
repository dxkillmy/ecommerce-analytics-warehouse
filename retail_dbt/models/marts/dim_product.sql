with codes as (
    select distinct stock_code
    from {{ source('staging', 'online_retail') }}
),

description_counts as (
    select stock_code, description, count(*) as n
    from {{ source('staging', 'online_retail') }}
    where description is not null
    group by stock_code, description
),

ranked as (
    select
        stock_code,
        description,
        row_number() over (
            partition by stock_code
            order by n desc, description
        ) as rn
    from description_counts
)

select
    c.stock_code,
    r.description
from codes c
left join ranked r
    on r.stock_code = c.stock_code
   and r.rn = 1