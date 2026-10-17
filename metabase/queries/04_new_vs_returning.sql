WITH monthly AS (
    SELECT DISTINCT
        f.customer_id,
        make_date(d.year_num, d.month_num, 1) AS month
    FROM analytics.fact_sales f
    JOIN analytics.dim_date d USING (date_day)
    WHERE f.has_customer
      AND NOT f.is_return
      AND f.date_day < '2011-12-01'
)
SELECT
    m.month,
    COUNT(*) FILTER (
        WHERE date_trunc('month', c.first_purchase_date)::date = m.month
    ) AS new_customers,
    COUNT(*) FILTER (
        WHERE date_trunc('month', c.first_purchase_date)::date < m.month
    ) AS returning_customers
FROM monthly m
JOIN analytics.dim_customer c USING (customer_id)
GROUP BY m.month
ORDER BY m.month;