# Data model

How the 9 Olist tables relate to each other. GitHub draws the diagram from the Mermaid code below. The counts come from the full dataset (99,441 orders).

```mermaid
erDiagram
    customers ||--|| orders : "places"
    orders ||--o{ order_items : "contains"
    products ||--o{ order_items : "is sold as"
    sellers ||--o{ order_items : "fulfils"
    orders ||--o{ order_payments : "is paid by"
    orders ||--o{ order_reviews : "is reviewed in"
    category_translation |o--o{ products : "names the category of"
    geolocation }o--o{ customers : "zip prefix"
    geolocation }o--o{ sellers : "zip prefix"

    customers {
        text customer_id PK "one per order"
        text customer_unique_id "the real person"
        text customer_zip_code_prefix
        text customer_city
        char customer_state
    }
    orders {
        text order_id PK
        text customer_id FK
        text order_status
        timestamp order_purchase_timestamp
        timestamp order_approved_at
        timestamp order_delivered_carrier_date
        timestamp order_delivered_customer_date
        timestamp order_estimated_delivery_date
    }
    order_items {
        text order_id PK, FK
        int order_item_id PK "1, 2, 3 within an order"
        text product_id FK
        text seller_id FK
        timestamp shipping_limit_date
        numeric price
        numeric freight_value
    }
    order_payments {
        text order_id PK, FK
        int payment_sequential PK
        text payment_type
        int payment_installments
        numeric payment_value
    }
    order_reviews {
        text review_id "not unique"
        text order_id FK
        int review_score "1 to 5"
        text review_comment_title
        text review_comment_message
        timestamp review_creation_date
        timestamp review_answer_timestamp
    }
    products {
        text product_id PK
        text product_category_name FK "Portuguese, can be blank"
        numeric product_weight_g
        numeric product_length_cm
        numeric product_height_cm
        numeric product_width_cm
    }
    sellers {
        text seller_id PK
        text seller_zip_code_prefix
        text seller_city
        char seller_state
    }
    category_translation {
        text product_category_name PK
        text product_category_name_english
    }
    geolocation {
        text geolocation_zip_code_prefix "many rows per prefix"
        float geolocation_lat
        float geolocation_lng
        text geolocation_city
        char geolocation_state
    }
```

`products` also has three descriptive columns left out of the diagram: `product_name_lenght`, `product_description_lenght` and `product_photos_qty` (the misspellings come from the source files).

**Reading the lines:** `||` means exactly one, `|o` zero or one, `o{` zero or many, `}o` many. For example, `orders ||--o{ order_items` means each order has zero or more items and each item belongs to exactly one order.

## The centre of the model: orders and order_items

`orders` is the hub. Every other table joins to it directly or through `order_items`.

| Relationship | Join on | In the data |
|---|---|---|
| order → items | `order_id` | 0 to 21 items per order. 775 orders have none (mostly unavailable or canceled). |
| item → product | `product_id` | Every product has been sold at least once. |
| item → seller | `seller_id` | One order can include items from up to 5 sellers. |
| order → payments | `order_id` | 1 to 29 payment rows per order (e.g. voucher + card). 1 order has none. |
| order → reviews | `order_id` | 98,673 orders have a review and 768 don't. Up to 3 reviews per order. |
| order → customer | `customer_id` | Exactly one order per `customer_id`. |

## Traps to avoid when joining

- **`customer_id` is not the customer.** Olist creates a new `customer_id` for every order, so the join to `orders` is one-to-one. To follow a real person across orders, use `customer_unique_id` (one person placed up to 17 orders).
- **Joining items multiplies rows.** `order_items` has one row per item, so joining it to `orders` repeats each order once per item. Count orders with `COUNT(DISTINCT order_id)`, or aggregate items per order first.
- **Joining payments and items together double-counts both.** An order with 2 items and 2 payments becomes 4 rows. Aggregate each table to one row per order before joining them.
- **Reviews aren't unique.** `review_id` repeats and 547 orders have more than one review, so average scores per order before joining (as the analysis queries do).
- **The category translation is optional.** 610 products have no category and 2 categories have no English name. Use a `LEFT JOIN` to `category_translation` and `COALESCE` to fall back to the Portuguese name or `'unknown'`.
- **Geolocation has no key.** One zip prefix has many latitude/longitude rows, so joining it directly to customers or sellers multiplies rows. Reduce it to one row per prefix first (for example, the average latitude and longitude), then join on the zip prefix. This is why the schema has no foreign key to it.

## Where the keys are enforced

- **PostgreSQL** adds the primary keys in [`01_create_tables.sql`](../sql/postgres/01_create_tables.sql) and the foreign keys and indexes after loading, in [`03_add_constraints.sql`](../sql/postgres/03_add_constraints.sql). If any row broke a relationship, adding the foreign keys would fail.
- **SQLite** declares the keys in [`01_create_tables.sql`](../sql/sqlite/01_create_tables.sql), and the loader checks them with `PRAGMA foreign_key_check`.
- [`data_quality_checks.sql`](../sql/checks/data_quality_checks.sql) re-checks the joins on both databases (no orphan orders, items, products or sellers).

## The Power BI star schema

Power BI doesn't read the raw tables. It reads views from [`05_powerbi_views.sql`](../sql/postgres/05_powerbi_views.sql), in a separate `powerbi` schema, arranged as a star schema: three fact tables, each at a single grain, sharing four dimensions. Because items, payments and reviews each live in their own fact, or are rolled up to the order first, none of the join traps above can double-count.

```mermaid
erDiagram
    dim_date ||--o{ fact_orders : "purchase_date"
    dim_date ||--o{ fact_order_items : "purchase_date"
    dim_date ||--o{ fact_payments : "purchase_date"
    dim_customer ||--o{ fact_orders : "customer_id"
    dim_customer ||--o{ fact_order_items : "customer_id"
    dim_customer ||--o{ fact_payments : "customer_id"
    dim_product ||--o{ fact_order_items : "product_id"
    dim_seller ||--o{ fact_order_items : "seller_id"
```

| View | One row per | Used for |
|---|---|---|
| `fact_orders` | order (99,441) | delivery time, lateness, review score, order value |
| `fact_order_items` | item sold (112,650) | revenue by category, product and seller |
| `fact_payments` | payment (103,883) | payment types and instalments |
| `dim_date` | day, Sep 2016 – Oct 2018 | trends by month, quarter, weekday |
| `dim_customer` | `customer_id` | state, region, city, real person (`customer_unique_id`) |
| `dim_product` | product | English category, weight, volume |
| `dim_seller` | seller | state, region, short code for charts |

Every fact has `is_completed` (not canceled or unavailable) and `in_analysis_window` (Jan 2017 – Aug 2018) flags, so the dashboard can use the same filters as the SQL analysis. `is_late` is stored as 0 or 1, so averaging it gives the late rate. States are grouped into Brazil's five regions.
