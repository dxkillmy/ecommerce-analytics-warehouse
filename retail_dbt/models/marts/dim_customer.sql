with customers as (
    select customer_id, country, invoice_date
    from {{ source('staging', 'online_retail') }}
    where has_customer
),

ranked as (
    select
        customer_id,
        country,
        row_number() over (
            partition by customer_id
            order by invoice_date desc
        ) as rn
    from customers
),

latest_country as (
    select customer_id, country
    from ranked
    where rn = 1
),

bounds as (
    select
        customer_id,
        min(invoice_date) as first_purchase_date,
        max(invoice_date) as last_purchase_date
    from customers
    group by customer_id
)

select
    b.customer_id,
    l.country,
    b.first_purchase_date,
    b.last_purchase_date
from bounds b
join latest_country l using (customer_id)