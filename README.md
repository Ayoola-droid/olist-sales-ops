# Olist E-commerce Sales & Operations Analysis

**Status:** in progress (data setup done; analysis and Power BI dashboard coming next)

An end-to-end analytics project on the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce): about 100k orders from 2016–2018 across 9 linked tables.

**Business question:** where is revenue coming from, and how do delivery delays affect customer reviews?

## Tools
- **SQL**: the same data model in both SQLite and PostgreSQL, with data-quality checks that run on both
- **Python**: a loader script that validates the files and bulk-loads either database
- **Power BI**: star schema, DAX measures and a two-page dashboard (to come)

## Repository layout
```
sql/postgres/   table definitions, \copy load, constraints, analysis queries
sql/sqlite/     table definitions and analysis queries
sql/checks/     portable data-quality checks
scripts/        load_data.py, run_pipeline.py (load + check + report in one command)
reports/        generated check results for each database
data/raw/       the Kaggle CSVs go here (not committed)
```

## Data quality findings

Checked with [`sql/checks/data_quality_checks.sql`](sql/checks/data_quality_checks.sql) after loading. All row counts match the published dataset, and no rows break the relationships between tables.

| Finding | What it means for the analysis |
|---|---|
| 99,441 orders but only 96,096 unique customers. `customer_id` is created per order. | Repeat-customer analysis must use `customer_unique_id`. Repeat buying is rare: only 2,997 customers (3.1%) ordered more than once. |
| 97% of orders are `delivered`. The other 3% are shipped, canceled, unavailable, invoiced, processing, created or approved, and almost none of them have a delivery date. | Delivery-time measures use delivered orders only. Revenue excludes canceled and unavailable orders. |
| 8 delivered orders have no delivery date, and 6 canceled orders do have one. | Status and dates contradict each other in a few rows. These are excluded from delivery-time measures. |
| 775 orders have no items, and 1 order has no payment. 767 of the 775 are `unavailable` (603) or `canceled` (164). | These are orders that never went through, so dropping them in an inner join to items is correct for revenue. Order counts still state which population they cover. |
| 789 review IDs are reused, and 547 orders have more than one review. | Review scores are averaged per order first, so no order is counted twice. |
| 610 products have no category, and 13 products are in 2 categories with no English name. | They are grouped as "Unknown" in category charts. |
| In 380 of 98,665 orders (0.4%), payments don't equal item price + freight. In 290 the customer paid more (average R$10.59 over, likely instalment interest); in 90 they paid less (average R$2.22 under, likely vouchers). | Revenue is based on item prices, not payments. |
| Orders run from Sept 2016 to Oct 2018, but the edges are sparse: 329 orders in all of 2016 (none in Nov 2016), and only 20 in Sept–Oct 2018, none delivered. | The analysis window is **Jan 2017 – Aug 2018** (20 complete months, 99,092 orders). |

## Reproduce it
See [SETUP.md](SETUP.md) for step-by-step setup on Windows.
