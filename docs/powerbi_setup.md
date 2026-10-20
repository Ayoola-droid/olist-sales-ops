# Power BI setup: connecting to PostgreSQL

How to connect Power BI Desktop (Windows, free) to the PostgreSQL database and build the star-schema model. It assumes the data is already loaded into PostgreSQL. See [SETUP.md](../SETUP.md), Part B.

## 1. Create the Power BI views

Power BI reads views from a separate `powerbi` schema, not the raw tables. The views are arranged as a star schema so nothing double-counts. See [data_model.md](data_model.md#the-power-bi-star-schema).

```powershell
cd C:\Projects\olist-sales-ops
$env:PGPASSWORD = "your-password"
psql -U postgres -d olist -f sql/postgres/05_powerbi_views.sql
```

It ends with *"Power BI views created in schema powerbi."* The script is safe to re-run.

## 2. Connect Power BI to PostgreSQL

1. **Get data** → **More…** → **Database** → **PostgreSQL database** → **Connect**.
2. **Server:** `localhost`. **Database:** `olist`. **Data Connectivity mode:** **Import**.
   Import copies the data into the `.pbix` file, which makes the visuals fast. Use **Refresh** on the Home tab after the database changes.
3. Credentials: use the **Database** tab, not Windows. User name `postgres` and your PostgreSQL password. Power BI keeps the password in your own Windows settings, not in the `.pbix` file, so the file is safe to share.
4. If it warns that it can't make an **encrypted connection**, click **OK** to continue without encryption. That's fine for a database on your own PC.

## 3. Load the seven views

In the Navigator, tick only these, then **Load**:

| Fact tables | Dimension tables |
|---|---|
| `powerbi.fact_orders` | `powerbi.dim_date` |
| `powerbi.fact_order_items` | `powerbi.dim_customer` |
| `powerbi.fact_payments` | `powerbi.dim_product` |
| | `powerbi.dim_seller` |

Leave out `powerbi.state_region`, a helper view, and the raw `public` tables.

## 4. Set up the relationships

Open **Model view** (the third icon on the left). The model needs exactly these **8 relationships**, each **Many to one (\*:1)** with **Single** cross-filter direction, so filters flow from the dimension to the fact:

| From (many) | To (one) | Notes |
|---|---|---|
| `fact_orders[purchase_date]` | `dim_date[date]` | create manually (names differ) |
| `fact_order_items[purchase_date]` | `dim_date[date]` | create manually |
| `fact_payments[purchase_date]` | `dim_date[date]` | create manually |
| `fact_orders[customer_id]` | `dim_customer[customer_id]` | check cardinality, see below |
| `fact_order_items[customer_id]` | `dim_customer[customer_id]` | auto-detected |
| `fact_payments[customer_id]` | `dim_customer[customer_id]` | auto-detected |
| `fact_order_items[product_id]` | `dim_product[product_id]` | auto-detected |
| `fact_order_items[seller_id]` | `dim_seller[seller_id]` | auto-detected |

To create one, drag a column from one table onto the matching column of the other. To change one, double-click its line to open **Edit relationship**.

### Fix what auto-detect gets wrong

Power BI links any columns with matching names, which causes two problems in this model:

- **Delete any fact-to-fact relationships.** Auto-detect links `fact_orders[order_id]` to `order_id` in `fact_order_items` and `fact_payments`. They usually appear as **dotted lines**, meaning inactive. Facts should only meet through shared dimensions, so select each of these lines and press **Delete**.
- **Change `dim_customer` → `fact_orders` from one-to-one to many-to-one.** Olist creates one `customer_id` per order, so the columns are unique on both sides and Power BI picks **One to one (1:1)** with **Both** directions. Edit it to **Many to one (\*:1)** with **Single** direction, so it behaves like every other dimension. Two-way filtering in a star schema can give confusing totals.

### Mark the date table

Select `dim_date` → **Table tools** → **Mark as date table** → choose the `date` column. This makes time-intelligence DAX (year-on-year, running totals) work properly.

## 5. Check the model

- Model view shows **8 solid lines**, all from a `dim_` table (the "1" side) to a `fact_` table (the "\*" side).
- No dotted lines, no lines between two facts, and no two-way arrows.
- A quick test: a card with `COUNTROWS(fact_orders)` shows **99,441**, and a table of `dim_customer[region]` with the average of `fact_orders[is_late]` shows the Northeast at about **12.7%**. Filter `fact_orders[is_delivered]` to True first.

## Notes

- **Refreshing:** after reloading the database or changing the views, click **Refresh** in Power BI.
- **Filters that match the SQL analysis:** every fact has `is_completed` (not canceled or unavailable) and `in_analysis_window` (Jan 2017 – Aug 2018). Apply them as filters on the page or report so the dashboard numbers match the README.
- **`is_late` is 0 or 1**, so its average is the late rate. It's empty for orders that weren't delivered, and DAX averages ignore those, which is what you want.
