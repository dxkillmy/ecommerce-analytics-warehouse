select
    f.total as fact_total,
    s.total as staging_total
from
    (select round(sum(line_amount), 2) as total
     from {{ ref('fact_sales') }}) f,
    (select round(sum((quantity * price)::numeric), 2) as total
     from {{ source('staging', 'online_retail') }}) s
where f.total <> s.total