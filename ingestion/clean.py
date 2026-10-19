import pandas as pd
from sqlalchemy import create_engine, text
import os

PGHOST = os.getenv("PGHOST", "localhost")
engine = create_engine(f"postgresql+psycopg2://retail:retail@{PGHOST}:5432/retail")

# 1) อ่านข้อมูลดิบ
df = pd.read_sql("SELECT * FROM raw.online_retail", engine)
print("raw rows:", len(df))

# 2) แปลง type
df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce")
df["price"] = pd.to_numeric(df["price"], errors="coerce")
df["invoice_date"] = pd.to_datetime(
    df["invoice_date"], format="%m/%d/%Y %H:%M", errors="coerce"
)

print(df.dtypes)
print(df[["quantity", "price", "invoice_date"]].isna().sum())

# 3) ลบแถวซ้ำ และติดธง
business_cols = [
    "invoice", "stock_code", "description", "quantity",
    "invoice_date", "price", "customer_id", "country",
]

before = len(df)
df = df.drop_duplicates(subset=business_cols)
print("duplicates removed:", before - len(df))

df["is_return"] = df["invoice"].str.startswith("C")
df["has_customer"] = df["customer_id"].notna()

# 4) แยกแถวที่ไม่ผ่านกฎ
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

# 5) เขียนลง staging
with engine.begin() as conn:
    conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))

clean.to_sql(
    "online_retail", engine, schema="staging",
    if_exists="replace", index=False, chunksize=50000,
)
rejected.to_sql(
    "rejected_rows", engine, schema="staging",
    if_exists="replace", index=False, chunksize=50000,
)
print("written to staging")