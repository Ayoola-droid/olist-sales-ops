-- How concentrated is revenue? Running total of revenue across product categories (Pareto / 80-20).
-- Item revenue excluding freight, Jan 2017 - Aug 2018, completed orders (same basis as revenue_by_category.sql).
--   sqlite3 -box olist.db ".read sql/analysis/revenue_concentration.sql"

-- Query 1: the running total, category by category
WITH category_sales AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        SUM(i.price) AS revenue
    FROM order_items i
    JOIN orders o   ON o.order_id = i.order_id
    JOIN products p ON p.product_id = i.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY 1
),
pareto AS (
    SELECT
        category,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC)                     AS category_rank,
        COUNT(*)     OVER ()                                          AS total_categories,
        100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / SUM(revenue) OVER ()                                  AS cumulative_pct
    FROM category_sales
)
SELECT
    category_rank,
    category,
    ROUND(revenue, 0)                                   AS revenue,
    ROUND(cumulative_pct, 1)                            AS cumulative_pct_of_revenue,
    ROUND(100.0 * category_rank / total_categories, 1)  AS pct_of_categories
FROM pareto
WHERE category_rank <= 20
ORDER BY category_rank;

-- Query 2: the headline numbers
WITH category_sales AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        SUM(i.price) AS revenue
    FROM order_items i
    JOIN orders o   ON o.order_id = i.order_id
    JOIN products p ON p.product_id = i.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY 1
),
pareto AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY revenue DESC)                     AS category_rank,
        COUNT(*)     OVER ()                                          AS total_categories,
        100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / SUM(revenue) OVER ()                                  AS cumulative_pct
    FROM category_sales
)
SELECT
    MAX(total_categories)                                         AS total_categories,
    MIN(CASE WHEN cumulative_pct >= 50 THEN category_rank END)    AS categories_for_50pct,
    MIN(CASE WHEN cumulative_pct >= 80 THEN category_rank END)    AS categories_for_80pct,
    MIN(CASE WHEN cumulative_pct >= 95 THEN category_rank END)    AS categories_for_95pct,
    ROUND(MAX(CASE WHEN category_rank <= ROUND(0.2 * total_categories) THEN cumulative_pct END), 1)
                                                                  AS top_20pct_share_of_revenue
FROM pareto;
