SELECT
    make_date(d.year_num, d.month_num, 1) AS month,
    ROUND(SUM(f.line_amount))             AS net_sales
FROM analytics.fact_sales f
JOIN analytics.dim_date d USING (date_day)
WHERE f.date_day < '2011-12-01'
GROUP BY 1
ORDER BY 1;