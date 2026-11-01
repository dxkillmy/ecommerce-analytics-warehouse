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
    r.description,
    np.stock_code is null
        and c.stock_code not ilike 'gift\_%'  as is_product,
    coalesce(np.category,
        case when c.stock_code ilike 'gift\_%' then 'voucher' end,
        'product')                           as product_category
from codes c
left join ranked r
    on r.stock_code = c.stock_code
   and r.rn = 1
left join {{ ref('non_product_codes') }} np
    on upper(c.stock_code) = upper(np.stock_code)