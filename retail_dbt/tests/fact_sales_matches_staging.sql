select
    f.total as fact_total,
    s.total as staging_total
from
    (select sum(line_amount) as total
     from {{ ref('fact_sales') }}) f,
    (select sum(quantity * price) as total
     from {{ source('staging', 'online_retail') }}) s
where f.total <> s.total