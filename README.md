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
scripts/        load_data.py
data/raw/       the Kaggle CSVs go here (not committed)
```

## Reproduce it
See [SETUP.md](SETUP.md) for step-by-step setup on Windows.
