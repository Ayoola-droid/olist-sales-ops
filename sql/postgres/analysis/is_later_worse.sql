-- Does it get worse the later the order is? Average review score by days late.
-- PostgreSQL version of sql/analysis/is_later_worse.sql
-- Subtracting two ::date values gives whole days (SQLite uses julianday instead).
--   psql -U postgres -d olist -f sql/postgres/analysis/is_later_worse.sql

SELECT
    lateness,
    COUNT(*)                      AS num_reviews,
    ROUND(AVG(review_score), 2)   AS avg_score
FROM (
    SELECT
        r.review_score,
        (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) AS days_late,
        CASE
            WHEN (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) <= 0 THEN '1. On time or early'
            WHEN (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) <= 3 THEN '2. 1-3 days late'
            WHEN (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) <= 7 THEN '3. 4-7 days late'
            ELSE '4. 8+ days late'
        END AS lateness
    FROM orders o
    JOIN order_reviews r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
) AS t
GROUP BY lateness
ORDER BY lateness;