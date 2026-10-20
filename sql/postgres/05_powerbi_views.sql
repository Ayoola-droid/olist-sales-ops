-- =============================================================
-- Star-schema views for Power BI, in their own schema: powerbi
--   psql -U postgres -d olist -f sql/postgres/05_powerbi_views.sql
-- Safe to re-run: drops and recreates the schema (the raw tables are untouched).
--
-- Three fact views, each at a single grain, so nothing double-counts:
--   fact_orders       one row per order        (delivery, lateness, reviews)
--   fact_order_items  one row per item sold    (revenue by product / seller)
--   fact_payments     one row per payment      (payment types, instalments)
-- Four dimension views shared by the facts:
--   dim_date, dim_customer, dim_product, dim_seller
-- Each fact carries is_completed and in_analysis_window flags, so the
-- dashboard can apply the same filters as the SQL analysis.
-- =============================================================
\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS powerbi CASCADE;
CREATE SCHEMA powerbi;

-- Brazilian states grouped into the five official regions (helper, not imported)
CREATE VIEW powerbi.state_region AS
SELECT state, region
FROM (VALUES
    ('AC','North'), ('AP','North'), ('AM','North'), ('PA','North'),
    ('RO','North'), ('RR','North'), ('TO','North'),
    ('AL','Northeast'), ('BA','Northeast'), ('CE','Northeast'), ('MA','Northeast'),
    ('PB','Northeast'), ('PE','Northeast'), ('PI','Northeast'), ('RN','Northeast'),
    ('SE','Northeast'),
    ('DF','Central-West'), ('GO','Central-West'), ('MT','Central-West'), ('MS','Central-West'),
    ('ES','Southeast'), ('MG','Southeast'), ('RJ','Southeast'), ('SP','Southeast'),
    ('PR','South'), ('RS','South'), ('SC','South')
) AS r(state, region);

-- ---------------------------------------------------------------- dimensions

CREATE VIEW powerbi.dim_date AS
SELECT
    d::date                                   AS date,
    EXTRACT(YEAR FROM d)::int                 AS year,
    'Q' || EXTRACT(QUARTER FROM d)::int       AS quarter,
    EXTRACT(MONTH FROM d)::int                AS month_number,
    TO_CHAR(d, 'Mon')                         AS month_name,
    TO_CHAR(d, 'YYYY-MM')                     AS year_month,
    DATE_TRUNC('month', d)::date              AS month_start,
    EXTRACT(ISODOW FROM d)::int               AS weekday_number,   -- 1 = Monday
    TO_CHAR(d, 'Dy')                          AS weekday_name,
    EXTRACT(ISODOW FROM d) IN (6, 7)          AS is_weekend
FROM GENERATE_SERIES(DATE '2016-09-01', DATE '2018-10-31', INTERVAL '1 day') AS g(d);

CREATE VIEW powerbi.dim_customer AS
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_city                            AS city,
    c.customer_state                           AS state,
    COALESCE(r.region, 'Unknown')              AS region
FROM customers c
LEFT JOIN powerbi.state_region r ON r.state = c.customer_state;

CREATE VIEW powerbi.dim_product AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    p.product_weight_g                                                            AS weight_g,
    p.product_length_cm * p.product_height_cm * p.product_width_cm                AS volume_cm3
FROM products p
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name;

CREATE VIEW powerbi.dim_seller AS
SELECT
    s.seller_id,
    LEFT(s.seller_id, 8)                       AS seller_code,   -- short label for charts
    s.seller_city                              AS city,
    s.seller_state                             AS state,
    COALESCE(r.region, 'Unknown')              AS region
FROM sellers s
LEFT JOIN powerbi.state_region r ON r.state = s.seller_state;

-- ---------------------------------------------------------------- facts

-- One row per order. Items and reviews are rolled up to the order first,
-- so joining them cannot multiply rows (see docs/data_model.md).
CREATE VIEW powerbi.fact_orders AS
WITH items AS (
    SELECT
        i.order_id,
        COUNT(*)                   AS items,
        SUM(i.price)               AS order_value,
        SUM(i.freight_value)       AS freight,
        CASE WHEN COUNT(p.product_weight_g) = COUNT(*) THEN SUM(p.product_weight_g) END AS weight_g
    FROM order_items i
    JOIN products p ON p.product_id = i.product_id
    GROUP BY i.order_id
),
reviews AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp::date                                   AS purchase_date,
    o.order_status,
    (o.order_status NOT IN ('canceled', 'unavailable'))                AS is_completed,
    (o.order_purchase_timestamp >= '2017-01-01'
     AND o.order_purchase_timestamp < '2018-09-01')                    AS in_analysis_window,
    (o.order_status = 'delivered'
     AND o.order_delivered_customer_date IS NOT NULL)                  AS is_delivered,
    CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
         THEN o.order_delivered_customer_date::date - o.order_purchase_timestamp::date END
                                                                       AS delivery_days,
    CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
         THEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date END
                                                                       AS days_late,
    CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
         THEN (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)::int END
                                                                       AS is_late,
    rv.review_score,
    COALESCE(it.items, 0)                                              AS items,
    it.order_value,
    it.freight,
    it.weight_g
FROM orders o
LEFT JOIN items   it ON it.order_id = o.order_id
LEFT JOIN reviews rv ON rv.order_id = o.order_id;

-- One row per item sold.
CREATE VIEW powerbi.fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    o.customer_id,
    o.order_purchase_timestamp::date                                   AS purchase_date,
    (o.order_status NOT IN ('canceled', 'unavailable'))                AS is_completed,
    (o.order_purchase_timestamp >= '2017-01-01'
     AND o.order_purchase_timestamp < '2018-09-01')                    AS in_analysis_window,
    i.price,
    i.freight_value
FROM order_items i
JOIN orders o ON o.order_id = i.order_id;

-- One row per payment (an order can have several, e.g. voucher + card).
CREATE VIEW powerbi.fact_payments AS
SELECT
    p.order_id,
    p.payment_sequential,
    o.customer_id,
    o.order_purchase_timestamp::date                                   AS purchase_date,
    (o.order_status NOT IN ('canceled', 'unavailable'))                AS is_completed,
    (o.order_purchase_timestamp >= '2017-01-01'
     AND o.order_purchase_timestamp < '2018-09-01')                    AS in_analysis_window,
    p.payment_type,
    p.payment_installments,
    CASE
        WHEN p.payment_installments <= 1  THEN '1. 1 instalment'
        WHEN p.payment_installments <= 3  THEN '2. 2-3'
        WHEN p.payment_installments <= 6  THEN '3. 4-6'
        WHEN p.payment_installments <= 10 THEN '4. 7-10'
        ELSE                                   '5. 11+'
    END                                                                AS instalment_band,
    p.payment_value
FROM order_payments p
JOIN orders o ON o.order_id = p.order_id
WHERE p.payment_type <> 'not_defined';

\echo 'Power BI views created in schema powerbi.'
