SELECT
    f.country,
    ROUND(SUM(f.line_amount)) AS net_sales
FROM analytics.fact_sales f
JOIN analytics.dim_product p USING (stock_code)
WHERE p.is_product
GROUP BY f.country
ORDER BY net_sales DESC
LIMIT 10;