-- Do heavier orders arrive later? Late rate, delivery time and freight by total order weight.
-- Delivered orders, Jan 2017 - Aug 2018. Orders with any item missing a weight are left out.
--   sqlite3 -box olist.db ".read sql/analysis/late_by_weight.sql"

WITH order_size AS (               -- one row per order: total weight, items, price and freight
    SELECT
        i.order_id,
        COUNT(*)                   AS items,
        SUM(p.product_weight_g)    AS weight_g,
        COUNT(p.product_weight_g)  AS items_with_weight,
        SUM(i.price)               AS goods_value,
        SUM(i.freight_value)       AS freight
    FROM order_items i
    JOIN products p ON p.product_id = i.product_id
    GROUP BY i.order_id
),
delivered AS (
    SELECT
        s.*,
        julianday(DATE(o.order_delivered_customer_date))
          - julianday(DATE(o.order_purchase_timestamp))            AS delivery_days,
        CASE WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
             THEN 1 ELSE 0 END                                   AS is_late
    FROM order_size s
    JOIN orders o ON o.order_id = s.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
      AND s.items_with_weight = s.items
)
SELECT
    CASE
        WHEN weight_g <   1000 THEN '1. Under 1 kg'
        WHEN weight_g <   5000 THEN '2. 1-5 kg'
        WHEN weight_g <  10000 THEN '3. 5-10 kg'
        WHEN weight_g <  20000 THEN '4. 10-20 kg'
        ELSE                        '5. 20 kg+'
    END                                                  AS order_weight,
    COUNT(*)                                             AS orders,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 1)            AS late_pct,
    ROUND(AVG(delivery_days), 1)                         AS avg_delivery_days,
    ROUND(AVG(freight), 2)                               AS avg_freight,
    ROUND(100.0 * SUM(freight) / SUM(goods_value), 1)    AS freight_pct_of_goods
FROM delivered
GROUP BY 1
ORDER BY 1;
