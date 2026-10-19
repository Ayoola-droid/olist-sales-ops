-- =============================================================
-- Follow-up checks on what data_quality_checks.sql found.
-- Portable: runs on both databases.
--   SQLite:      sqlite3 -box olist.db ".read sql/checks/follow_up_checks.sql"
--   PostgreSQL:  psql -U postgres -d olist -f sql/checks/follow_up_checks.sql
-- =============================================================

-- 1. Orders per month: are the first and last months complete?
--    (CAST to text + SUBSTR works the same way in both databases)
SELECT SUBSTR(CAST(order_purchase_timestamp AS TEXT), 1, 7) AS month,
       COUNT(*) AS orders,
       SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered
FROM orders
GROUP BY 1
ORDER BY 1;

-- 2. The 775 orders with no items: what status are they?
SELECT o.order_status, COUNT(*) AS orders_with_no_items
FROM orders o
LEFT JOIN order_items i ON i.order_id = o.order_id
WHERE i.order_id IS NULL
GROUP BY o.order_status
ORDER BY 2 DESC;

-- 3. Status contradictions
SELECT 'canceled but has a delivery date' AS check_name, COUNT(*) AS orders
FROM orders
WHERE order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL
UNION ALL
SELECT 'delivered but no delivery date', COUNT(*)
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
UNION ALL
SELECT 'delivered before it was bought', COUNT(*)
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp
ORDER BY check_name;

-- 4. Real repeat customers (by customer_unique_id)
WITH per_person AS (
    SELECT c.customer_unique_id, COUNT(*) AS orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS customers,
       SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_pct
FROM per_person;

-- 5. Orders where payments do not equal items + freight (by more than 1 cent): by how much?
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM order_items GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM order_payments GROUP BY order_id
)
SELECT CASE WHEN p.paid_total > i.items_total THEN 'paid more than charged'
            ELSE 'paid less than charged' END AS direction,
       COUNT(*) AS orders,
       ROUND(AVG(ABS(p.paid_total - i.items_total)), 2) AS avg_gap,
       ROUND(MAX(ABS(p.paid_total - i.items_total)), 2) AS max_gap
FROM item_totals i
JOIN payment_totals p ON p.order_id = i.order_id
WHERE ROUND(ABS(i.items_total - p.paid_total), 2) > 0.01
GROUP BY 1;
