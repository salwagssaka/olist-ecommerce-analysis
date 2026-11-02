"""Load the Olist CSV files into a local MySQL database.

Usage (PowerShell):
    $env:MYSQL_PASSWORD = "your_password"
    $env:OLIST_DATA_DIR = "C:\\path\\to\\olist_csv_folder"
    python 01_import_data.py

The password is read from an environment variable so it never ends up in the repository.
"""
import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

DATA_DIR = Path(os.environ.get("OLIST_DATA_DIR", "data"))

# URL.create escapes special characters (such as %) in the password
engine = create_engine(
    URL.create(
        "mysql+pymysql",
        username=os.environ.get("MYSQL_USER", "root"),
        password=os.environ["MYSQL_PASSWORD"],
        host=os.environ.get("MYSQL_HOST", "localhost"),
        database=os.environ.get("MYSQL_DATABASE", "project1"),
    )
)

# CSV file name -> table name used by the queries in sql/olist_analysis_queries.sql
TABLES = {
    "olist_customers_dataset": "customers",
    "olist_geolocation_dataset": "geolocation",
    "olist_order_items_dataset": "order_items",
    "olist_order_payments_dataset": "order_payments",
    "olist_order_reviews_dataset": "order_reviews",
    "olist_orders_dataset": "orders",
    "olist_products_dataset": "products",
    "olist_sellers_dataset": "sellers",
    "product_category_name_translation": "product_category",
}

for file in sorted(DATA_DIR.glob("*.csv")):
    table = TABLES.get(file.stem.lower(), file.stem.lower().replace(" ", "_"))
    df = pd.read_csv(file)
    df.to_sql(name=table, con=engine, if_exists="replace", index=False)
    print(f"Imported {file.name} -> {table} ({len(df):,} rows)")

print("All CSV files imported successfully!")
