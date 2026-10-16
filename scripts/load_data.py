"""
Load the Olist e-commerce CSVs into SQLite or PostgreSQL.

    py scripts/load_data.py --db sqlite                 # creates olist.db
    py scripts/load_data.py --db postgres --user postgres --dbname olist

Run it from the project folder. SQLite needs nothing extra (it is built into
Python). PostgreSQL needs:  py -m pip install "psycopg[binary]"

What it does, in order:
  1. checks all 9 CSVs exist and their headers are what the schema expects
  2. creates the tables from sql/<db>/... (drops them first, so it is re-runnable)
  3. loads every file, turning empty fields into NULL
  4. checks relationships (foreign keys) and prints row counts
"""

import argparse
import csv
import getpass
import os
import sqlite3
import sys
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

# table name -> (csv file name, expected header)
TABLES = {
    "customers": ("olist_customers_dataset.csv",
                  ["customer_id", "customer_unique_id", "customer_zip_code_prefix",
                   "customer_city", "customer_state"]),
    "sellers": ("olist_sellers_dataset.csv",
                ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"]),
    "category_translation": ("product_category_name_translation.csv",
                             ["product_category_name", "product_category_name_english"]),
    "products": ("olist_products_dataset.csv",
                 ["product_id", "product_category_name", "product_name_lenght",
                  "product_description_lenght", "product_photos_qty", "product_weight_g",
                  "product_length_cm", "product_height_cm", "product_width_cm"]),
    "orders": ("olist_orders_dataset.csv",
               ["order_id", "customer_id", "order_status", "order_purchase_timestamp",
                "order_approved_at", "order_delivered_carrier_date",
                "order_delivered_customer_date", "order_estimated_delivery_date"]),
    "order_items": ("olist_order_items_dataset.csv",
                    ["order_id", "order_item_id", "product_id", "seller_id",
                     "shipping_limit_date", "price", "freight_value"]),
    "order_payments": ("olist_order_payments_dataset.csv",
                       ["order_id", "payment_sequential", "payment_type",
                        "payment_installments", "payment_value"]),
    "order_reviews": ("olist_order_reviews_dataset.csv",
                      ["review_id", "order_id", "review_score", "review_comment_title",
                       "review_comment_message", "review_creation_date",
                       "review_answer_timestamp"]),
    "geolocation": ("olist_geolocation_dataset.csv",
                    ["geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng",
                     "geolocation_city", "geolocation_state"]),
}


def check_files(data_dir: Path) -> None:
    """Fail early, with a clear message, if a file is missing or has unexpected columns."""
    problems = []
    for table, (fname, expected) in TABLES.items():
        path = data_dir / fname
        if not path.exists():
            problems.append(f"missing: {path}")
            continue
        with open(path, newline="", encoding="utf-8-sig") as f:
            header = next(csv.reader(f))
        if header != expected:
            problems.append(f"unexpected columns in {fname}: {header}")
    if problems:
        sys.exit("Cannot load:\n  " + "\n  ".join(problems)
                 + "\nDownload the Olist dataset from Kaggle and unzip it into " + str(data_dir))
    print(f"All 9 files found in {data_dir} with the expected columns.")


def sql_without_psql_commands(path: Path) -> str:
    """Strip psql-only lines (\\set, \\echo) so the file can run through a driver."""
    return "\n".join(line for line in path.read_text(encoding="utf-8").splitlines()
                     if not line.lstrip().startswith("\\"))


# ---------------------------------------------------------------- SQLite
def load_sqlite(data_dir: Path, db_path: Path) -> None:
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = OFF")      # check after loading, not during
    conn.executescript((PROJECT / "sql/sqlite/01_create_tables.sql").read_text(encoding="utf-8"))

    for table, (fname, columns) in TABLES.items():
        start = time.time()
        placeholders = ", ".join("?" for _ in columns)
        insert = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({placeholders})"
        with open(data_dir / fname, newline="", encoding="utf-8-sig") as f:
            reader = csv.reader(f)
            next(reader)                            # skip header
            rows = ([value if value != "" else None for value in row] for row in reader)
            conn.executemany(insert, rows)
        conn.commit()
        count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"  {table:<22} {count:>9,} rows  ({time.time() - start:.1f}s)")

    violations = conn.execute("PRAGMA foreign_key_check").fetchall()
    if violations:
        summary = {}
        for table, _rowid, parent, _fk in violations:
            summary[(table, parent)] = summary.get((table, parent), 0) + 1
        print("Foreign-key problems (worth noting in your data-quality log):")
        for (table, parent), n in summary.items():
            print(f"  {n:,} rows in {table} point to a missing {parent}")
    else:
        print("Foreign keys: no orphan rows.")
    conn.execute("ANALYZE")
    conn.close()
    print(f"SQLite database ready: {db_path}")


# ------------------------------------------------------------ PostgreSQL
def load_postgres(data_dir: Path, args) -> None:
    try:
        import psycopg
    except ImportError:
        sys.exit('psycopg is not installed. Run:  py -m pip install "psycopg[binary]"')

    password = os.environ.get("PGPASSWORD") or getpass.getpass(f"Password for {args.user}: ")
    conn = psycopg.connect(host=args.host, port=args.port, user=args.user,
                           dbname=args.dbname, password=password)
    with conn, conn.cursor() as cur:
        cur.execute("SET client_encoding = 'UTF8'")
        cur.execute(sql_without_psql_commands(PROJECT / "sql/postgres/01_create_tables.sql"))

        for table, (fname, columns) in TABLES.items():
            start = time.time()
            copy_sql = (f"COPY {table} ({', '.join(columns)}) FROM STDIN "
                        "WITH (FORMAT csv, HEADER true)")
            with open(data_dir / fname, "rb") as f, cur.copy(copy_sql) as copy:
                while chunk := f.read(1 << 20):     # stream 1 MB at a time
                    copy.write(chunk)
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            print(f"  {table:<22} {cur.fetchone()[0]:>9,} rows  ({time.time() - start:.1f}s)")

        print("Adding foreign keys and indexes...")
        cur.execute(sql_without_psql_commands(PROJECT / "sql/postgres/03_add_constraints.sql"))
    conn.close()
    print(f"PostgreSQL database ready: {args.dbname} on {args.host}:{args.port}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Load the Olist CSVs into SQLite or PostgreSQL.")
    parser.add_argument("--db", choices=["sqlite", "postgres"], required=True)
    parser.add_argument("--data-dir", default=PROJECT / "data/raw", type=Path)
    parser.add_argument("--sqlite-path", default=PROJECT / "olist.db", type=Path)
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", default=5432, type=int)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--dbname", default="olist")
    args = parser.parse_args()

    check_files(args.data_dir)
    started = time.time()
    if args.db == "sqlite":
        load_sqlite(args.data_dir, args.sqlite_path)
    else:
        load_postgres(args.data_dir, args)
    print(f"Finished in {time.time() - started:.1f}s")


if __name__ == "__main__":
    main()
