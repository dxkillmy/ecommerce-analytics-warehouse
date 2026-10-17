SELECT
    country,
    ROUND(SUM(line_amount)) AS net_sales
FROM analytics.fact_sales
GROUP BY country
ORDER BY net_sales DESC
LIMIT 10;