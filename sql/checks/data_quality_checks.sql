-- =============================================================
-- Data-quality checks: the SAME file runs on both databases.
--   PostgreSQL:  psql -U postgres -d olist -f sql/checks/data_quality_checks.sql
--   SQLite:      sqlite3 olist.db ".read sql/checks/data_quality_checks.sql"
-- Only standard SQL is used here (CTEs, LEFT JOIN, CASE, COUNT),
-- which is why it is portable. Copy the results into your
-- project's data-quality note.
-- =============================================================

-- 1. Row counts: compare against the Kaggle page
SELECT 'customers'            AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers',              COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'products',             COUNT(*) FROM products
UNION ALL SELECT 'orders',               COUNT(*) FROM orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments',       COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation',          COUNT(*) FROM geolocation
ORDER BY table_name;

-- 2. Orders by status, with missing delivery dates
SELECT order_status,
       COUNT(*) AS orders,
       SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_delivery_date
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 3. Date range covered
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM orders;

-- 4. Duplicate review IDs (why order_reviews has no primary key)
SELECT COUNT(*) AS review_ids_used_more_than_once
FROM (SELECT review_id FROM order_reviews GROUP BY review_id HAVING COUNT(*) > 1) d;

-- 5. Orders with more than one review
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) d;

-- 6. Customers vs real people (customer_id is per order)
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- 7. Orphan checks: each should be 0 (PostgreSQL's foreign keys enforce this)
SELECT 'orders without customer' AS check_name, COUNT(*) AS problem_rows
FROM orders o LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'items without product', COUNT(*)
FROM order_items i LEFT JOIN products p ON p.product_id = i.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'items without seller', COUNT(*)
FROM order_items i LEFT JOIN sellers s ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'orders with no items', COUNT(*)
FROM orders o LEFT JOIN order_items i ON i.order_id = o.order_id
WHERE i.order_id IS NULL
UNION ALL
SELECT 'orders with no payment', COUNT(*)
FROM orders o LEFT JOIN order_payments p ON p.order_id = o.order_id
WHERE p.order_id IS NULL
ORDER BY check_name;

-- 8. Product categories with no English translation
SELECT p.product_category_name, COUNT(*) AS products
FROM products p
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY products DESC;

-- 9. Do payments match what was charged (items + freight)?
--    ROUND(..., 2) compares whole cents. Without it, SQLite's floating-point sums
--    count some exact 1-cent differences as slightly more than 0.01.
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM order_items GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM order_payments GROUP BY order_id
)
SELECT COUNT(*) AS orders_compared,
       SUM(CASE WHEN ROUND(ABS(i.items_total - p.paid_total), 2) > 0.01 THEN 1 ELSE 0 END) AS orders_not_matching
FROM item_totals i
JOIN payment_totals p ON p.order_id = i.order_id;
