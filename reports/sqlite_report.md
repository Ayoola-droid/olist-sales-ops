# SQLite pipeline report
Generated 2026-10-19 18:13 by `scripts/run_pipeline.py` in 4.0s.

## Automatic checks

- PASS: every table has rows
- PASS: no orphan customers, products or sellers

## `sql/checks/data_quality_checks.sql`

### 1. Row counts: compare against the Kaggle page

| table_name | row_count |
|---|---|
| category_translation | 71 |
| customers | 99,441 |
| geolocation | 1,000,163 |
| order_items | 112,650 |
| order_payments | 103,886 |
| order_reviews | 99,224 |
| orders | 99,441 |
| products | 32,951 |
| sellers | 3,095 |

### 2. Orders by status, with missing delivery dates

| order_status | orders | missing_delivery_date |
|---|---|---|
| delivered | 96,478 | 8 |
| shipped | 1,107 | 1,107 |
| canceled | 625 | 619 |
| unavailable | 609 | 609 |
| invoiced | 314 | 314 |
| processing | 301 | 301 |
| created | 5 | 5 |
| approved | 2 | 2 |

### 3. Date range covered

| first_order | last_order |
|---|---|
| 2016-09-04 21:15:19 | 2018-10-17 17:30:18 |

### 4. Duplicate review IDs (why order_reviews has no primary key)

| review_ids_used_more_than_once |
|---|
| 789 |

### 5. Orders with more than one review

| orders_with_multiple_reviews |
|---|
| 547 |

### 6. Customers vs real people (customer_id is per order)

| customer_ids | unique_customers |
|---|---|
| 99,441 | 96,096 |

### 7. Orphan checks: each should be 0 (PostgreSQL's foreign keys enforce this)

| check_name | problem_rows |
|---|---|
| items without product | 0 |
| items without seller | 0 |
| orders with no items | 775 |
| orders with no payment | 1 |
| orders without customer | 0 |

### 8. Product categories with no English translation

| product_category_name | products |
|---|---|
| (blank) | 610 |
| portateis_cozinha_e_preparadores_de_alimentos | 10 |
| pc_gamer | 3 |

### 9. Do payments match what was charged (items + freight)?

| orders_compared | orders_not_matching |
|---|---|
| 98,665 | 303 |

## `sql/checks/follow_up_checks.sql`

### 1. Orders per month: are the first and last months complete?

| month | orders | delivered |
|---|---|---|
| 2016-09 | 4 | 1 |
| 2016-10 | 324 | 265 |
| 2016-12 | 1 | 1 |
| 2017-01 | 800 | 750 |
| 2017-02 | 1,780 | 1,653 |
| 2017-03 | 2,682 | 2,546 |
| 2017-04 | 2,404 | 2,303 |
| 2017-05 | 3,700 | 3,546 |
| 2017-06 | 3,245 | 3,135 |
| 2017-07 | 4,026 | 3,872 |
| 2017-08 | 4,331 | 4,193 |
| 2017-09 | 4,285 | 4,150 |
| 2017-10 | 4,631 | 4,478 |
| 2017-11 | 7,544 | 7,289 |
| 2017-12 | 5,673 | 5,513 |
| 2018-01 | 7,269 | 7,069 |
| 2018-02 | 6,728 | 6,555 |
| 2018-03 | 7,211 | 7,003 |
| 2018-04 | 6,939 | 6,798 |
| 2018-05 | 6,873 | 6,749 |
| 2018-06 | 6,167 | 6,099 |
| 2018-07 | 6,292 | 6,159 |
| 2018-08 | 6,512 | 6,351 |
| 2018-09 | 16 | 0 |
| 2018-10 | 4 | 0 |

### 2. The 775 orders with no items: what status are they?

| order_status | orders_with_no_items |
|---|---|
| unavailable | 603 |
| canceled | 164 |
| created | 5 |
| invoiced | 2 |
| shipped | 1 |

### 3. Status contradictions

| check_name | orders |
|---|---|
| canceled but has a delivery date | 6 |
| delivered before it was bought | 0 |
| delivered but no delivery date | 8 |

### 4. Real repeat customers (by customer_unique_id)

| customers | repeat_customers | repeat_pct |
|---|---|---|
| 96,096 | 2,997 | 3.12 |

### 5. Orders where payments do not equal items + freight (by more than 1 cent): by how much?

| direction | orders | avg_gap | max_gap |
|---|---|---|---|
| paid less than charged | 39 | 5.1 | 51.62 |
| paid more than charged | 264 | 11.63 | 182.81 |

## `sql/sqlite/02_monthly_revenue.sql`

### Monthly revenue

| month | revenue | orders | avg_order_value | pct_change_vs_prev_month |
|---|---|---|---|---|
| 2017-01 | 120098.27 | 787 | 152.6 | (blank) |
| 2017-02 | 244959.35 | 1,718 | 142.58 | 104.0 |
| 2017-03 | 368341.32 | 2,617 | 140.75 | 50.4 |
| 2017-04 | 353842.98 | 2,377 | 148.86 | -3.9 |
| 2017-05 | 503159.19 | 3,640 | 138.23 | 42.2 |
| 2017-06 | 429916.61 | 3,205 | 134.14 | -14.6 |
| 2017-07 | 492287.3 | 3,946 | 124.76 | 14.5 |
| 2017-08 | 568245.79 | 4,272 | 133.02 | 15.4 |
| 2017-09 | 621415.91 | 4,227 | 147.01 | 9.4 |
| 2017-10 | 660179.62 | 4,547 | 145.19 | 6.2 |
| 2017-11 | 1003862.14 | 7,421 | 135.27 | 52.1 |
| 2017-12 | 742183.79 | 5,618 | 132.11 | -26.1 |
| 2018-01 | 945456.29 | 7,187 | 131.55 | 27.4 |
| 2018-02 | 837895.43 | 6,624 | 126.49 | -11.4 |
| 2018-03 | 981051.06 | 7,168 | 136.87 | 17.1 |
| 2018-04 | 993592.98 | 6,919 | 143.6 | 1.3 |
| 2018-05 | 992871.75 | 6,833 | 145.31 | -0.1 |
| 2018-06 | 863265.53 | 6,145 | 140.48 | -13.1 |
| 2018-07 | 878044.27 | 6,233 | 140.87 | 1.7 |
| 2018-08 | 848860.1 | 6,421 | 132.2 | -3.3 |
