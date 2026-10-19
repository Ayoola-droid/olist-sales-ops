-- How long do repeat customers take to order again?
-- Days from a customer's first order to their second (customer_unique_id = the real person).
--   sqlite3 -box olist.db ".read sql/analysis/time_to_second_order.sql"

WITH customer_orders AS (          -- every order, numbered within each customer
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                           ORDER BY o.order_purchase_timestamp)  AS order_number,
        LAG(o.order_purchase_timestamp) OVER (PARTITION BY c.customer_unique_id
                                              ORDER BY o.order_purchase_timestamp) AS previous_order_at
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
second_orders AS (                 -- one row per repeat customer
    SELECT
        customer_unique_id,
        julianday(order_purchase_timestamp) - julianday(previous_order_at) AS days_to_second
    FROM customer_orders
    WHERE order_number = 2
)
SELECT
    CASE
        WHEN days_to_second < 1   THEN '1. Same day'
        WHEN days_to_second <= 30  THEN '2. 1-30 days'
        WHEN days_to_second <= 90  THEN '3. 31-90 days'
        WHEN days_to_second <= 180 THEN '4. 91-180 days'
        ELSE                            '5. Over 180 days'
    END                                                   AS time_to_second_order,
    COUNT(*)                                              AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_repeaters,
    ROUND(AVG(days_to_second), 1)                         AS avg_days
FROM second_orders
GROUP BY 1
ORDER BY 1;
