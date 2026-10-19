-- Do late deliveries go with worse reviews?
-- Delivered orders only. 'Late' = delivered on a later calendar day than the estimate.
--   sqlite3 -box olist.db ".read sql/analysis/late_delivery_reviews.sql"

SELECT
    CASE
        WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
        THEN 'Late'
        ELSE 'On time'
    END AS delivery_status,
    COUNT(*)                      AS num_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                  AS pct_one_star
FROM orders o
JOIN order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status
ORDER BY delivery_status;
