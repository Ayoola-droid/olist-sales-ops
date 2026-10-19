-- Which product categories bring in the most revenue?
-- Item revenue (price, excluding freight), Jan 2017 - Aug 2018, completed orders only.
--   sqlite3 -box olist.db ".read sql/analysis/revenue_by_category.sql"

WITH category_sales AS (
    SELECT
        COALESCE(t.product_category_name_english,
                 p.product_category_name,
                 'unknown')                   AS category,
        COUNT(*)                              AS items_sold,
        COUNT(DISTINCT i.order_id)            AS orders,
        SUM(i.price)                          AS revenue,
        AVG(i.price)                          AS avg_item_price
    FROM order_items i
    JOIN orders o        ON o.order_id = i.order_id
    JOIN products p      ON p.product_id = i.product_id
    LEFT JOIN category_translation t
                         ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY 1
)
SELECT
    category,
    items_sold,
    orders,
    ROUND(revenue, 0)                                  AS revenue,
    ROUND(avg_item_price, 2)                           AS avg_item_price,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)   AS pct_of_revenue
FROM category_sales
ORDER BY revenue DESC
LIMIT 15;