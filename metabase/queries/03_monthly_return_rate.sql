SELECT
    make_date(d.year_num, d.month_num, 1) AS month,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_return THEN -f.line_amount ELSE 0 END)
        / NULLIF(SUM(CASE WHEN NOT f.is_return THEN f.line_amount ELSE 0 END), 0),
        2
    ) AS return_rate_pct
FROM analytics.fact_sales f
JOIN analytics.dim_date d USING (date_day)
WHERE f.date_day < '2011-12-01'
GROUP BY 1
ORDER BY 1;