-- =============================================================
-- Add foreign keys and indexes AFTER the data is loaded.
--   psql -U postgres -d olist -f sql/postgres/03_add_constraints.sql
-- If a foreign key fails, PostgreSQL names the offending value:
-- that is a data-quality finding worth writing up, not just an error.
-- =============================================================
\set ON_ERROR_STOP on

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer  FOREIGN KEY (customer_id) REFERENCES customers (customer_id);
ALTER TABLE order_items
    ADD CONSTRAINT fk_items_order      FOREIGN KEY (order_id)    REFERENCES orders (order_id),
    ADD CONSTRAINT fk_items_product    FOREIGN KEY (product_id)  REFERENCES products (product_id),
    ADD CONSTRAINT fk_items_seller     FOREIGN KEY (seller_id)   REFERENCES sellers (seller_id);
ALTER TABLE order_payments
    ADD CONSTRAINT fk_payments_order   FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_reviews
    ADD CONSTRAINT fk_reviews_order    FOREIGN KEY (order_id)    REFERENCES orders (order_id);

-- Deliberately NO foreign key from products to category_translation:
-- a few Portuguese category names have no English translation.
-- The data-quality checks list them.

-- Indexes on the columns you will join and filter on most
CREATE INDEX idx_orders_customer      ON orders (customer_id);
CREATE INDEX idx_orders_purchase_ts   ON orders (order_purchase_timestamp);
CREATE INDEX idx_items_product        ON order_items (product_id);
CREATE INDEX idx_items_seller         ON order_items (seller_id);
CREATE INDEX idx_reviews_order        ON order_reviews (order_id);
CREATE INDEX idx_customers_unique     ON customers (customer_unique_id);
CREATE INDEX idx_geo_zip              ON geolocation (geolocation_zip_code_prefix);

\echo 'Constraints and indexes added.'
