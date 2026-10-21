import glob
import os
import psycopg2

CSV_FILES = sorted(glob.glob('data/archive/*.csv'))

if not CSV_FILES:
    raise SystemExit("No CSV files found in data/archive/.")

conn = psycopg2.connect(
    host=os.getenv("PGHOST", "localhost"), port=5432,
    dbname="retail", user="retail", password="retail",
)

cur = conn.cursor()

with open("ingestion/create_raw.sql") as f:
    cur.execute(f.read())
    
cur.execute("TRUNCATE raw.online_retail;")

for path in CSV_FILES:
    with open(path, "r", encoding="utf-8") as f:
        cur.copy_expert(
            """COPY raw.online_retail
               (invoice, stock_code, description, quantity,
                invoice_date, price, customer_id, country)
               FROM STDIN WITH (FORMAT csv, HEADER true)""",
            f,
        )
    cur.execute(
        "UPDATE raw.online_retail SET source_file = %s WHERE source_file IS NULL",
        (os.path.basename(path),),
    )
    print("loaded:", path)

conn.commit()

cur.execute("SELECT source_file, COUNT(*) FROM raw.online_retail GROUP BY source_file ORDER BY 1;")
for row in cur.fetchall():
    print(row)

cur.close()
conn.close()