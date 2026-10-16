-- =============================================================
-- Olist e-commerce: table definitions for PostgreSQL
-- Run with:  psql -U postgres -d olist -f sql/postgres/01_create_tables.sql
-- Safe to re-run: drops and recreates every table.
-- Foreign keys are added AFTER loading (03_add_constraints.sql),
-- so a bad row shows up as a finding instead of a failed load.
-- =============================================================
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
    products, sellers, customers, geolocation, category_translation CASCADE;

CREATE TABLE customers (
    customer_id               TEXT PRIMARY KEY,   -- one per order
    customer_unique_id        TEXT NOT NULL,      -- the real person: use this for repeat-customer analysis
    customer_zip_code_prefix  TEXT,
    customer_city             TEXT,
    customer_state            CHAR(2)
);

CREATE TABLE sellers (
    seller_id                 TEXT PRIMARY KEY,
    seller_zip_code_prefix    TEXT,
    seller_city               TEXT,
    seller_state              CHAR(2)
);

CREATE TABLE category_translation (
    product_category_name          TEXT PRIMARY KEY,
    product_category_name_english  TEXT
);

CREATE TABLE products (
    product_id                  TEXT PRIMARY KEY,
    product_category_name       TEXT,
    product_name_lenght         NUMERIC,   -- spelling kept as in the source file
    product_description_lenght  NUMERIC,
    product_photos_qty          NUMERIC,
    product_weight_g            NUMERIC,
    product_length_cm           NUMERIC,
    product_height_cm           NUMERIC,
    product_width_cm            NUMERIC
);

CREATE TABLE orders (
    order_id                       TEXT PRIMARY KEY,
    customer_id                    TEXT NOT NULL,
    order_status                   TEXT,
    order_purchase_timestamp       TIMESTAMP,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
);

CREATE TABLE order_items (
    order_id             TEXT NOT NULL,
    order_item_id        INTEGER NOT NULL,   -- 1, 2, 3 ... within an order
    product_id           TEXT NOT NULL,
    seller_id            TEXT NOT NULL,
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2),
    freight_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id              TEXT NOT NULL,
    payment_sequential    INTEGER NOT NULL,
    payment_type          TEXT,
    payment_installments  INTEGER,
    payment_value         NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- No primary key on purpose: review_id repeats in the source data.
-- The data-quality checks count those duplicates.
CREATE TABLE order_reviews (
    review_id                TEXT NOT NULL,
    order_id                 TEXT NOT NULL,
    review_score             INTEGER,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP
);

-- No key: many rows per zip prefix (one per lat/long sample).
CREATE TABLE geolocation (
    geolocation_zip_code_prefix  TEXT,
    geolocation_lat              DOUBLE PRECISION,
    geolocation_lng              DOUBLE PRECISION,
    geolocation_city             TEXT,
    geolocation_state            CHAR(2)
);
