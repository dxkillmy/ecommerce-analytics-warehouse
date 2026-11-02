import os
import csv
from io import StringIO
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.types import Integer, Numeric

def copy_insert(table, conn, keys, data_iter):
    dbapi_conn = conn.connection
    with dbapi_conn.cursor() as cur:
        buf = StringIO()
        csv.writer(buf).writerows(data_iter)
        buf.seek(0)
        cols = ", ".join(f'"{k}"' for k in keys)
        cur.copy_expert(
            f'COPY {table.schema}."{table.name}" ({cols}) FROM STDIN WITH CSV',
            buf,
        )

PGHOST = os.getenv("PGHOST", "localhost")
engine = create_engine(f"postgresql+psycopg2://retail:retail@{PGHOST}:5432/retail")

df = pd.read_sql("SELECT * FROM raw.online_retail", engine)
print("raw rows:", len(df))

df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce")
df["price"] = pd.to_numeric(df["price"], errors="coerce")
df["invoice_date"] = pd.to_datetime(
    df["invoice_date"], format="%m/%d/%Y %H:%M", errors="coerce"
)

print(df.dtypes)
print(df[["quantity", "price", "invoice_date"]].isna().sum())

business_cols = [
    "invoice", "stock_code", "description", "quantity",
    "invoice_date", "price", "customer_id", "country",
]

before = len(df)
df = df.drop_duplicates(subset=business_cols)
print("duplicates removed:", before - len(df))

df["is_return"] = df["invoice"].str.startswith("C")
df["has_customer"] = df["customer_id"].notna()

bad_price = df["price"] <= 0
bad_qty = (df["quantity"] <= 0) & ~df["is_return"]
reject_mask = bad_price | bad_qty

rejected = df[reject_mask].copy()
rejected["reject_reason"] = "quantity_non_positive"
rejected.loc[bad_price[reject_mask], "reject_reason"] = "price_non_positive"

clean = df[~reject_mask].copy()

print("rejected rows:", len(rejected))
print(rejected["reject_reason"].value_counts())
print("clean rows:", len(clean))

col_types = {
    "quantity": Integer(),
    "price": Numeric(12, 3),
}
clean["quantity"] = clean["quantity"].astype("Int64")
rejected["quantity"] = rejected["quantity"].astype("Int64")

with engine.begin() as conn:
    conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))

clean.to_sql(
    "online_retail", engine, schema="staging",
    if_exists="replace", index=False, chunksize=50000,
    dtype=col_types, method=copy_insert,
)
rejected.to_sql(
    "rejected_rows", engine, schema="staging",
    if_exists="replace", index=False, chunksize=50000,
    dtype=col_types,
)
print("written to staging")