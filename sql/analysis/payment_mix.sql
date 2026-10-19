-- How do customers pay? Payment types, value and instalments.
-- Completed orders, Jan 2017 - Aug 2018. One order can use more than one payment (e.g. voucher + card).
--   sqlite3 -box olist.db ".read sql/analysis/payment_mix.sql"

-- Query 1: payment types, with instalments pivoted into columns
SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id)                                         AS orders,
    ROUND(100.0 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 1)
                                                                       AS pct_of_value,
    ROUND(AVG(p.payment_value), 2)                                     AS avg_payment,
    ROUND(AVG(p.payment_installments), 1)                              AS avg_instalments,
    ROUND(100.0 * SUM(CASE WHEN p.payment_installments <= 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                                       AS pct_1_instalment,
    ROUND(100.0 * SUM(CASE WHEN p.payment_installments BETWEEN 2 AND 5 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                                       AS pct_2_to_5,
    ROUND(100.0 * SUM(CASE WHEN p.payment_installments BETWEEN 6 AND 10 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                                       AS pct_6_to_10,
    ROUND(100.0 * SUM(CASE WHEN p.payment_installments > 10 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                                       AS pct_over_10
FROM order_payments p
JOIN orders o ON o.order_id = p.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
  AND p.payment_type <> 'not_defined'
GROUP BY p.payment_type
ORDER BY pct_of_value DESC;

-- Query 2: credit cards only - do bigger payments get split into more instalments?
SELECT
    CASE
        WHEN p.payment_installments <= 1  THEN '1. 1 instalment'
        WHEN p.payment_installments <= 3  THEN '2. 2-3'
        WHEN p.payment_installments <= 6  THEN '3. 4-6'
        WHEN p.payment_installments <= 10 THEN '4. 7-10'
        ELSE                                   '5. 11+'
    END                                                   AS instalments,
    COUNT(*)                                              AS payments,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_card_payments,
    ROUND(AVG(p.payment_value), 2)                        AS avg_payment
FROM order_payments p
JOIN orders o ON o.order_id = p.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
  AND p.payment_type = 'credit_card'
GROUP BY 1
ORDER BY 1;
