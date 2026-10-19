-- Who are the best and worst sellers? Revenue, late rate and reviews, ranked.
-- Delivered orders, Jan 2017 - Aug 2018, sellers with 50+ delivered orders.
--   sqlite3 -box olist.db ".read sql/analysis/seller_ranking.sql"

WITH seller_orders AS (            -- one row per seller per order
    SELECT
        i.seller_id,
        i.order_id,
        SUM(i.price) AS revenue,
        MAX(CASE WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
                 THEN 1 ELSE 0 END) AS is_late
    FROM order_items i
    JOIN orders o ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY i.seller_id, i.order_id
),
order_scores AS (                  -- one review score per order
    SELECT order_id, AVG(review_score) AS score
    FROM order_reviews
    GROUP BY order_id
),
seller_stats AS (                  -- one row per seller
    SELECT
        so.seller_id,
        COUNT(*)                            AS orders,
        SUM(so.revenue)                     AS revenue,
        100.0 * SUM(so.is_late) / COUNT(*)  AS late_pct,
        AVG(s.score)                        AS avg_review
    FROM seller_orders so
    LEFT JOIN order_scores s ON s.order_id = so.order_id
    GROUP BY so.seller_id
    HAVING COUNT(*) >= 50
)
SELECT
    RANK() OVER (ORDER BY st.revenue DESC)    AS revenue_rank,
    SUBSTR(st.seller_id, 1, 8)                AS seller,
    se.seller_state                           AS state,
    st.orders,
    ROUND(st.revenue, 0)                      AS revenue,
    ROUND(st.late_pct, 1)                     AS late_pct,
    ROUND(st.avg_review, 2)                   AS avg_review,
    RANK() OVER (ORDER BY st.avg_review DESC) AS review_rank,
    COUNT(*) OVER ()                          AS sellers_ranked
FROM seller_stats st
JOIN sellers se ON se.seller_id = st.seller_id
ORDER BY revenue_rank
LIMIT 15;
