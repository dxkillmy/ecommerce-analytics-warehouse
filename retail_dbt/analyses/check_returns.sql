-- check_returns.sql
-- Why did the return rate drop after excluding non-product codes?
-- I wanted to check which codes were actually pushing the return rate up.
--
-- How to run (from the project folder):
--   docker compose exec -T postgres psql -U retail -d retail < retail_dbt/analyses/check_returns.sql
--
-- Notes:
--   * return rate = value of returns / value of sales (by money, not by number of orders)
--   * returns have negative line_amount, so I flip the sign with a minus
--   * all queries skip December 2011, because the data stops on 9 Dec 2011
--     (same rule as the dashboard)


-- 1) Returned vs sold value for each product category
select p.product_category,
       count(*) as rows,
       round(sum(case when f.is_return then -f.line_amount else 0 end), 2) as returned,
       round(sum(case when not f.is_return then f.line_amount else 0 end), 2) as sold
from analytics.fact_sales f
join analytics.dim_product p on p.stock_code = f.stock_code
where f.date_day < '2011-12-01'
group by 1
order by returned desc;


-- 2) Overall return rate: all codes vs real products only
select
  round(100.0 * sum(case when f.is_return then -f.line_amount else 0 end)
              / sum(case when not f.is_return then f.line_amount else 0 end), 2) as rate_all,
  round(100.0 * sum(case when f.is_return and p.is_product then -f.line_amount else 0 end)
              / sum(case when not f.is_return and p.is_product then f.line_amount else 0 end), 2) as rate_products_only
from analytics.fact_sales f
join analytics.dim_product p on p.stock_code = f.stock_code
where f.date_day < '2011-12-01';


-- 3) Top non-product codes by returned value
select f.stock_code, p.product_category,
       count(*) as rows,
       round(sum(-f.line_amount), 2) as returned
from analytics.fact_sales f
join analytics.dim_product p on p.stock_code = f.stock_code
where f.is_return
  and not p.is_product
  and f.date_day < '2011-12-01'
group by 1, 2
order by returned desc
limit 10;


-- 4) How big are adjustments + fees compared to everything?
--    pct_rows           = share of all rows
--    pct_returned_value = share of all returned value
select
  round(100.0 * count(*) filter (where p.product_category in ('adjustment', 'fee'))
              / count(*), 2) as pct_rows,
  round(100.0 * sum(-f.line_amount) filter (where f.is_return and p.product_category in ('adjustment', 'fee'))
              / sum(-f.line_amount) filter (where f.is_return), 1) as pct_returned_value
from analytics.fact_sales f
join analytics.dim_product p on p.stock_code = f.stock_code
where f.date_day < '2011-12-01';