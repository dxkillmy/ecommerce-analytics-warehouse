select
    md5(concat_ws('|',
        invoice, stock_code, coalesce(description, ''),
        quantity::text, invoice_date::text, price::text,
        coalesce(customer_id, ''), country
    ))                              as sales_key,
    invoice,
    invoice_date,
    invoice_date::date              as date_day,
    customer_id,
    stock_code,
    country,
    quantity,
    price                           as unit_price,
    round((quantity * price)::numeric, 2) as line_amount,
    is_return,
    has_customer
from {{ source('staging', 'online_retail') }}