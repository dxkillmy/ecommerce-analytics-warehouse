# E-commerce Analytics Warehouse

A small data pipeline I built to practice data engineering. It takes about 1 million rows of online store sales, cleans them, organizes them into tables that are easy to analyze, and shows the results on a dashboard. Everything runs on my laptop with Docker.

- Data: [Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii), sales from a UK online gift shop (Dec 2009 to Dec 2011)
- Tools: Python, pandas, PostgreSQL, dbt, Airflow, Docker, Metabase

![Dashboard](docs/images/dashboard.png)

## How it works

The data goes through four steps. Each step saves its result in its own schema (a group of tables) in PostgreSQL.

```
CSV files -> raw -> staging -> analytics -> Metabase dashboard
```

1. **raw**: `load_raw.py` loads the CSV files exactly as they are. Every column is stored as text, so dirty values cannot break the load.
2. **staging**: `clean.py` uses pandas to remove duplicates, fix data types and flag problem rows.
3. **analytics**: dbt turns the clean data into a star schema (explained below) and runs tests on it.
4. **Metabase** reads the analytics tables and shows the charts.

I keep the raw layer so that if I find a bug in the cleaning, I can fix it and run again without downloading anything.

Every step can be run again safely. It replaces its own tables, so nothing gets duplicated.

## Cleaning

I checked the raw data with SQL first, then decided what to do with each problem:

- 34,335 rows were exact duplicates. I removed them. They come from two places:
  - 22,844 rows appear in both files, because the two yearly files overlap in December 2010.
  - 11,491 rows are repeated inside the same file. The data has no line number for each invoice line, so I can't be 100% sure these are mistakes and not the same item bought twice. I decided to remove them because they match on every column, including the exact minute. They are only about 1% of the data.
- 6,019 rows had a price of 0 or less. I moved them to `staging.rejected_rows` instead of deleting them, so I can always see what was removed.
- About 23% of rows had no customer ID. I kept them because they are real sales, and marked them with `has_customer = false`.
- Invoices starting with `C` are returns. I kept them and marked them `is_return = true` so I can measure returns.

The numbers add up: 1,067,371 raw rows - 34,335 duplicates = 1,033,036 = 1,027,017 clean rows + 6,019 rejected rows.

At first, writing the clean data to staging took about 11 minutes inside the Airflow container. pandas `to_sql` inserts rows in small batches, which is slow for 1 million rows. It was so slow that I thought the task was stuck. I changed it to use PostgreSQL `COPY` (the same way `load_raw.py` loads the CSV files), and now the whole `clean.py` step takes about 1.5 minutes.

## Rows that are not products

Some stock codes are not real products. For example `POST` and `DOT` are postage, `AMAZONFEE` and `BANK CHARGES` are fees, and `M` and `ADJUST` are manual adjustments. At first I counted them as sales, which made the numbers wrong.

I put these codes in a small CSV file (`retail_dbt/seeds/non_product_codes.csv`) and load it with `dbt seed`. `dim_product` uses it to set `is_product = false`, and the dashboard only counts rows where `is_product = true`.

| Category | Rows | Amount |
|---|---:|---:|
| product | 1,021,254 | 18,927,436 |
| shipping | 3,771 | 433,411 |
| fee | 152 | -264,936 |
| adjustment | 1,748 | -83,590 |
| voucher | 78 | 1,687 |
| test | 14 | 204 |

The biggest change was the return rate. Amazon fees are stored as returns, so before this fix the monthly return rate was mostly 3-9%. After the fix it is mostly 1.5-6%.

## The tables

A star schema has one big table with the events (sales) and small tables that describe them (who, what, when).

| Table | One row is... | Rows |
|---|---|---:|
| `fact_sales` | one line on an invoice | 1,027,017 |
| `dim_customer` | one customer | 5,939 |
| `dim_product` | one product | 4,932 |
| `dim_date` | one calendar day | 739 |

The data has no unique ID for each invoice line, so I made one (`sales_key`) by hashing all the columns together.

`dim_product` also has `is_product` and `product_category`, so I can filter out postage, fees and adjustments.

## Tests

dbt runs 14 tests, and all pass:

- Every ID is unique and not empty.
- Every sale points to a customer, product and date that exist.
- The total sales amount in `fact_sales` matches the total in staging exactly.

At first this test failed by a small amount (0.018 on 19 million). The reason was that `price` was stored as a float, and floats can't store most decimal numbers exactly. When you add up 1 million of them, the tiny errors add up too. Even summing the same rows in a different order gave a different result in the 7th decimal place. I changed `price` to `numeric` and `quantity` to `integer` in staging, and stopped rounding each line in `fact_sales`. Now the two totals are exactly the same, with no tolerance.

## Dashboard

There are four charts. The SQL for each one is in `metabase/queries/`.

1. Monthly net sales: sales peak in November in both years.
2. Top 10 countries: the United Kingdom is most of the revenue.
3. Monthly return rate: the value of returned items as a percent of sales. The spike in January 2011 comes from one order. On 18 January 2011, customer 12346 bought 74,215 units of one product (77,184) and cancelled the whole order 16 minutes later. I kept it because it really happened, but it makes that month look much worse than normal.
4. New vs returning customers: from early 2010, there are more returning customers than new ones in most months.

In the three monthly charts, December 2011 is left out because the data stops on 9 December. In December 2009 every customer counts as new because the data starts there.

All charts only count real products (`is_product = true`).

## Folders

```
data/archive/        CSV files (not in git)
ingestion/           load_raw.py, clean.py, create_raw.sql
retail_dbt/          dbt project (models, seeds, tests)
metabase/queries/    SQL for the dashboard charts
docker-compose.yml   PostgreSQL, Airflow and Metabase
airflow/             Airflow image and the DAG
```

## Scheduling with Airflow

An Airflow DAG called `retail_pipeline` runs the whole pipeline every day. It has five tasks that run in order: `load_raw`, `clean`, `dbt_seed`, `dbt_run` and `dbt_test`. If a task fails, Airflow tries it again up to 2 times. If it still fails, the tasks after it do not run, and the failed task turns red so I can see the problem. If a data test fails, it also shows up as a red task instead of going unnoticed.

The pipeline code runs in its own Python environment inside the Airflow image, because Airflow and dbt need different package versions.

![Airflow success](docs/images/airflow_success.png)
![Airflow failed](docs/images/airflow_failed.png)

## How to run

You need Docker and the two CSV files from the dataset.

### Option 1: with Airflow

1. **Download the data first.** The CSV files are not in this repo because they are too big, so you have to add them yourself. Download the dataset (link at the top) and put the two files here:
   - `data/archive/online_retail_09_10.csv`
   - `data/archive/online_retail_10_11.csv`

   Check with `ls data/archive`. You should see both files. If the folder is empty, the load step will stop with an error.

2. Start everything. The first build takes a few minutes:

   ```bash
   docker compose up -d --build
   ```

3. Wait 2 to 3 minutes, then open http://localhost:8080 and log in with `admin` / `admin`. Switch on `retail_pipeline` and press the play button to run it.

4. When all five tasks are green, open Metabase at http://localhost:3000, create an account, and add a PostgreSQL database (host `postgres`, port `5432`, database `retail`, user `retail`, password `retail`). Then create the charts from the SQL files in `metabase/queries/`.

### Option 2: without Airflow

You also need Python 3.9 or newer. Do step 1 above first, then:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
docker compose up -d postgres metabase
python ingestion/load_raw.py
python ingestion/clean.py
cd retail_dbt
dbt seed
dbt run
dbt test
```

Then do step 4 above for Metabase.