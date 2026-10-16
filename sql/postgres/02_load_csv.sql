-- =============================================================
-- Load the 9 Olist CSVs into PostgreSQL with psql's \copy
-- Run FROM THE PROJECT FOLDER (paths below are relative to it):
--   psql -U postgres -d olist -f sql/postgres/02_load_csv.sql
--
-- \copy (with a backslash) reads the file from YOUR computer and
-- streams it to the server, so it needs no special server permissions.
-- Each \copy must stay on a single line.
-- =============================================================
\set ON_ERROR_STOP on

TRUNCATE customers, sellers, category_translation, products, orders,
    order_items, order_payments, order_reviews, geolocation;

\echo 'Loading customers...'
\copy customers FROM 'data/raw/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading sellers...'
\copy sellers FROM 'data/raw/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading category_translation...'
\copy category_translation FROM 'data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading products...'
\copy products FROM 'data/raw/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading orders...'
\copy orders FROM 'data/raw/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading order_items...'
\copy order_items FROM 'data/raw/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading order_payments...'
\copy order_payments FROM 'data/raw/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading order_reviews...'
\copy order_reviews FROM 'data/raw/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\echo 'Loading geolocation (about 1 million rows, give it a moment)...'
\copy geolocation FROM 'data/raw/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Refresh planner statistics after a bulk load
ANALYZE;
\echo 'Done. Next: sql/postgres/03_add_constraints.sql'
