# DAX measures

All the measures in `olist_dashboard.pbix`. They sit in a dedicated `_Measures` table. Every core number was checked against the SQL analysis: Revenue R$ 13,449,530, 97,910 orders, 6.8% late rate, 12.5 delivery days and 4.12 average review all match exactly.

**Table names in the model:** after import, the views from [`05_powerbi_views.sql`](../sql/postgres/05_powerbi_views.sql) were renamed to `orders` (fact_orders), `order_items` (fact_order_items), `payments` (fact_payments), `customer`, `product`, `seller` and `dim_date`.

**Report filter:** `dim_date[date]` is on or after 1 Jan 2017 and before 1 Sep 2018, set under *Filters on all pages*. One filter on the date table covers all three facts.

## Sales

```dax
Revenue = CALCULATE ( SUM ( order_items[price] ), order_items[is_completed] = TRUE () )

Orders = CALCULATE ( COUNTROWS ( orders ), orders[is_completed] = TRUE () )

Avg Order Value = DIVIDE ( [Revenue], [Orders] )

Freight % of Revenue =
DIVIDE (
    CALCULATE ( SUM ( order_items[freight_value] ), order_items[is_completed] = TRUE () ),
    [Revenue]
)

Payment Value = CALCULATE ( SUM ( payments[payment_value] ), payments[is_completed] = TRUE () )
```

- `CALCULATE(..., is_completed = TRUE())` builds the "exclude canceled and unavailable orders" rule into each measure, so every visual follows the same rule as the SQL analysis.
- `DIVIDE` returns blank instead of an error when dividing by zero.
- Payment Value is higher than Revenue because payments include freight.

## Time intelligence

```dax
Revenue LY = CALCULATE ( [Revenue], SAMEPERIODLASTYEAR ( dim_date[date] ) )

Revenue YoY % = DIVIDE ( [Revenue] - [Revenue LY], [Revenue LY] )

Revenue Running Total =
CALCULATE (
    [Revenue],
    FILTER ( ALLSELECTED ( dim_date[date] ), dim_date[date] <= MAX ( dim_date[date] ) )
)
```

- These need `dim_date` to be marked as the date table.
- YoY is only meaningful by month or year. Across the whole window, "last year" is Sep 2016 – Aug 2017, which had only about 8 months of trading, so the overall figure (+330%) is misleading. By month, Aug 2018 vs Aug 2017 is **+49.4%**.

## Operations

```dax
Delivered Orders = CALCULATE ( COUNTROWS ( orders ), orders[is_delivered] = TRUE () )

Late Rate = AVERAGE ( orders[is_late] )

Avg Delivery Days = AVERAGE ( orders[delivery_days] )

Avg Review = CALCULATE ( AVERAGE ( orders[review_score] ), orders[is_completed] = TRUE () )
```

- `is_late` is 1 or 0, and blank for undelivered orders. Averaging it gives the late rate, and DAX skips the blanks.
- `review_score` is already averaged per order in the view, so orders with several reviews are not counted twice.

## Seller-level measures (filtering across facts)

```dax
Late Rate (by seller) =
CALCULATE ( [Late Rate], TREATAS ( VALUES ( order_items[order_id] ), orders[order_id] ) )

Avg Review (by seller) =
CALCULATE ( [Avg Review], TREATAS ( VALUES ( order_items[order_id] ), orders[order_id] ) )
```

`seller` is related only to `order_items`, but lateness and reviews live in `orders`. Without `TREATAS`, a seller filter never reaches `orders`, and every seller shows the overall 6.8%. `TREATAS` takes the order IDs in the current seller's `order_items` and applies them as a filter on `orders[order_id]`. The results match the SQL seller ranking: identical late rates, and reviews within 0.02.

## Calculated column

On the `orders` table. It's a column, not a measure, because each order needs its own label:

```dax
Lateness Band =
SWITCH (
    TRUE (),
    ISBLANK ( orders[days_late] ), BLANK (),
    orders[days_late] <= 0, "1. On time or early",
    orders[days_late] <= 3, "2. 1-3 days late",
    orders[days_late] <= 7, "3. 4-7 days late",
    "4. 8+ days late"
)
```

The number prefixes make the bands sort in order on a chart axis.
