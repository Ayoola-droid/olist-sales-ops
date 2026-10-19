-- Where do late deliveries happen? Late rate, delivery time and reviews by customer state.
-- PostgreSQL version of sql/analysis/late_by_state.sql
--   psql -U postgres -d olist -f sql/postgres/analysis/late_by_state.sql

WITH delivered AS (
    SELECT
        o.order_id,
        c.customer_state AS state,
        (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)            AS delivery_days,
        CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
             THEN 1 ELSE 0 END                                   AS is_late
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
order_scores AS (
    SELECT order_id, AVG(review_score) AS score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    d.state,
    COUNT(*)                                    AS delivered_orders,
    SUM(d.is_late)                              AS late_orders,
    ROUND(100.0 * SUM(d.is_late) / COUNT(*), 1) AS late_pct,
    ROUND(AVG(d.delivery_days), 1)              AS avg_delivery_days,
    ROUND(AVG(s.score), 2)                      AS avg_review
FROM delivered d
LEFT JOIN order_scores s ON s.order_id = d.order_id
GROUP BY d.state
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC;