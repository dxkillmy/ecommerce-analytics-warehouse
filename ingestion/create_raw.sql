CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.online_retail;

CREATE TABLE raw.online_retail (
    invoice      TEXT,
    stock_code   TEXT,
    description  TEXT,
    quantity     TEXT,
    invoice_date TEXT,
    price        TEXT,
    customer_id  TEXT,
    country      TEXT,
    source_file  TEXT
);