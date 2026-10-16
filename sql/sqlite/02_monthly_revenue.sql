-- First real query, SQLite flavour: monthly revenue with month-on-month change.
--   sqlite3 olist.db ".read sql/sqlite/02_monthly_revenue.sql"
-- Compare with sql/postgres/04_monthly_revenue.sql: same logic, different date functions.
-- (Window functions like LAG need SQLite 3.25 or newer. Current downloads are fine.)
.headers on
.mode column
WITH monthly AS (
    SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month,
           SUM(i.price)                                   AS revenue,
           COUNT(DISTINCT o.order_id)                     AS orders
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
)
SELECT month,
       ROUND(revenue, 2)                                                     AS revenue,
       orders,
       ROUND(revenue / orders, 2)                                            AS avg_order_value,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1)            AS pct_change_vs_prev_month
FROM monthly
ORDER BY month;
