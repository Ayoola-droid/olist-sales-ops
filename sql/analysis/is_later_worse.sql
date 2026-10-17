-- Does it get worse the later the order is? Average review score by days late.
-- SQLite version (julianday). In PostgreSQL, subtract the two ::date values instead.
--   sqlite3 -box olist.db ".read sql/analysis/is_later_worse.sql"

SELECT
    lateness,
    COUNT(*)                      AS num_reviews,
    ROUND(AVG(review_score), 2)   AS avg_score
FROM (
    SELECT
        r.review_score,
        julianday(DATE(o.order_delivered_customer_date))
          - julianday(DATE(o.order_estimated_delivery_date)) AS days_late,
        CASE
            WHEN julianday(DATE(o.order_delivered_customer_date))
               - julianday(DATE(o.order_estimated_delivery_date)) <= 0 THEN '1. On time or early'
            WHEN julianday(DATE(o.order_delivered_customer_date))
               - julianday(DATE(o.order_estimated_delivery_date)) <= 3 THEN '2. 1-3 days late'
            WHEN julianday(DATE(o.order_delivered_customer_date))
               - julianday(DATE(o.order_estimated_delivery_date)) <= 7 THEN '3. 4-7 days late'
            ELSE '4. 8+ days late'
        END AS lateness
    FROM orders o
    JOIN order_reviews r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
) AS t
GROUP BY lateness
ORDER BY lateness;