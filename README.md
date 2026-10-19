# Olist E-commerce Sales & Operations Analysis

**Status:** in progress (data setup and 10 SQL analysis queries done; PostgreSQL and the Power BI dashboard next)

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
sql/analysis/   10 business questions (late deliveries, revenue, sellers, repeat customers, payments)
scripts/        load_data.py, run_pipeline.py (load + check + report in one command)
reports/        generated check results for each database
data/raw/       the Kaggle CSVs go here (not committed)
```

## Findings

### Late deliveries are strongly associated with poor reviews

Delivered orders, with review scores (1–5 stars). Queries: [`late_delivery_reviews.sql`](sql/analysis/late_delivery_reviews.sql) and [`is_later_worse.sql`](sql/analysis/is_later_worse.sql).

| Delivery | Reviews | Avg score | 1-star reviews |
|---|---:|---:|---:|
| On time or early | 89,944 | 4.29 | 6.6% |
| Late (all) | 6,409 | 2.27 | 53.7% |
| 1–3 days late | 1,856 | 3.29 | |
| 4–7 days late | 1,756 | 2.10 | |
| 8+ days late | 2,797 | 1.70 | |

- Late orders averaged **2.27 stars against 4.29** for on-time orders, and **over half (53.7%) got a 1-star review**, compared with 6.6% of on-time orders.
- **Scores fall with every step of lateness.** Even a 1–3 day delay costs a full star. A steady drop like this is stronger evidence than a single gap between two groups, though it still shows association rather than proof of cause.
- **When orders are late, they are often very late.** 44% of late orders arrived 8+ days after the estimate, so cutting severe delays should come first.
- Checks: the lateness groups sum to the late total (1,856 + 1,756 + 2,797 = 6,409). Counting each order once instead of each review, to handle orders with multiple reviews, gives the same averages (2.27 vs 4.29).

### Where late deliveries happen

Query: [`late_by_state.sql`](sql/analysis/late_by_state.sql). States with 100+ delivered orders (AC, AP and RR excluded).

- **The northeast is least reliable.** Alagoas is late on 21.4% of orders, nearly 5× São Paulo (4.5%). The six worst states are all in the northeast.
- **Rio de Janeiro is the biggest problem by volume.** It handles 12.8% of orders but 23.3% of all late deliveries. Improving Rio would help the most customers.
- **Slow is not the same as late.** Amazonas has the slowest deliveries (26.4 days) but only 2.8% arrive late, so estimates for remote states appear to be set generously. Late rate measures broken promises, not speed.
- **Reviews follow reliability.** Across states, late rate and average review are strongly negatively correlated (r = −0.90).

### Which categories bring in the most revenue

Query: [`revenue_by_category.sql`](sql/analysis/revenue_by_category.sql). Item revenue excluding freight, Jan 2017 – Aug 2018, completed orders.

- **Two routes to revenue.** Bed, bath & table sells the most items (11,089) but ranks 3rd, at R$93 per item. Watches & gifts sells about half as many but ranks 2nd, at R$200 per item, the highest in the top 15. Health & beauty leads by combining both.
- **Volume alone isn't enough.** Telephony sells more items than toys, baby or perfumery but ranks 14th, at R$71 per item.
- **Revenue is spread out at the top, concentrated overall.** The largest category is only 9.3% of revenue and the top 5 make 39.9%, but the top 15 of 74 categories (20%) bring in 76%.

### Who are the best and worst sellers

Query: [`seller_ranking.sql`](sql/analysis/seller_ranking.sql). Delivered orders, Jan 2017 – Aug 2018, 424 sellers with 50+ orders.

- **Big isn't always good.** Two of the top 5 sellers by revenue rank 376th and 411th of 424 on reviews (3.85 and 3.50 stars) across about 2,750 orders, so their problems reach the most customers.
- **Lateness is only part of the story.** Sellers #4 and #5 have almost the same late rate (9.2% vs 9.1%) but average 4.37 vs 3.50 stars. Across sellers, late rate and reviews are only moderately linked (r = −0.52, against −0.90 across states), so product and service quality matter too.
- **A reliable northeast seller.** The #2 seller (Bahia) earns its revenue from high-value orders (about R$626 each) and has the lowest late rate in the top 15 (3.4%).
- **Sales are concentrated.** The 424 sellers with 50+ orders are 14% of all 2,945 sellers but bring in 68% of delivered revenue. 12 of the top 15 are in São Paulo.

### How long do repeat customers take to order again

Query: [`time_to_second_order.sql`](sql/analysis/time_to_second_order.sql). Excludes canceled and unavailable orders.

| Time to second order | Customers | Share |
|---|---:|---:|
| Same day | 896 | 31.0% |
| 1–30 days | 571 | 19.8% |
| 31–90 days | 504 | 17.5% |
| 91–180 days | 419 | 14.5% |
| Over 180 days | 498 | 17.2% |

- **Most "same day" repeats aren't real returns.** 774 of the 896 placed both orders within 10 minutes, so they are one shopping trip split into two orders.
- **True repeat buying is about 2%.** Excluding same-day orders, only 1,992 of 94,990 customers (2.1%) came back.
- **Real returns are slow.** The median gap for genuine repeat customers is about 77 days, and 17% take more than six months.
- **The window to win customers back is 1–3 months.** A follow-up timed 30–60 days after the first order would reach customers when they are most likely to return.

### How concentrated is revenue

Query: [`revenue_concentration.sql`](sql/analysis/revenue_concentration.sql). Running total of category revenue, same basis as the category analysis.

| Share of revenue | Categories needed | Share of categories |
|---|---:|---:|
| 50% | 8 | 11% |
| 80% | 18 | 24% |
| 95% | 34 | 46% |

- **Almost exactly 80/20.** The top 20% of categories (15 of 74) bring in 76.3% of revenue.
- **A long tail.** The other 40 categories, more than half the catalogue, bring in only 5% between them.
- **Focus is cheap.** Delivery, seller and marketing improvements aimed at about 18 categories would cover 80% of the business. Whether to cut the tail depends on its costs, which this dataset doesn't include.
- **The same pattern as sellers.** 14% of sellers earn 68% of revenue, so a small core drives the business on both sides.

### Do heavier orders arrive later

Query: [`late_by_weight.sql`](sql/analysis/late_by_weight.sql). Delivered orders, Jan 2017 – Aug 2018, grouped by total order weight.

| Order weight | Orders | Late | Avg delivery days | Freight as % of goods |
|---|---:|---:|---:|---:|
| Under 1 kg | 54,449 | 6.5% | 12.0 | 17.6% |
| 1–5 kg | 28,679 | 6.9% | 12.7 | 15.4% |
| 5–10 kg | 7,778 | 7.0% | 13.4 | 16.1% |
| 10–20 kg | 4,024 | 8.7% | 14.6 | 16.4% |
| 20 kg+ | 1,257 | 9.5% | 15.3 | 18.8% |

- **Weight matters a little; location matters a lot.** Late rates rise from 6.5% to 9.5% with weight, about 1.5×, against a 5× gap between states (4.0% to 21.4%). Regional logistics should come before bulky-item handling.
- **Most orders are small.** 57% of delivered orders weigh under 1 kg, and only 1.3% weigh 20 kg or more.
- **Small orders pay the most for delivery relative to price.** Freight is 15–19% of goods value at every weight, but highest for the lightest orders (17.6%), which suggests a free-shipping threshold or bundling could help.
- **Caveat:** weight and destination are not separated here, so part of the weight effect could come from where heavy orders are sent.

### How customers pay

Query: [`payment_mix.sql`](sql/analysis/payment_mix.sql). Completed orders, Jan 2017 – Aug 2018.

| Payment type | Orders | Share of value | Avg payment | Split into instalments |
|---|---:|---:|---:|---:|
| Credit card | 75,390 | 78.5% | R$163 | 66.8% |
| Boleto (bank slip) | 19,479 | 18.0% | R$145 | n/a |
| Voucher | 3,734 | 2.2% | R$62 | n/a |
| Debit card | 1,513 | 1.4% | R$140 | n/a |

- **Credit cards dominate** with 78.5% of payment value. Boleto covers about 1 in 5 orders, likely customers without a card.
- **Instalments are the norm.** Two-thirds of card payments are split, 20.5% into 6–10 instalments.
- **Instalments fund bigger purchases.** Card payments of 7–10 instalments average R$331, about 3.5× single payments (R$96).
- **Implication:** interest-free instalment offers matter most for high-value categories such as watches & gifts. Boleto customers can't split payments and may respond to different offers.
- This also explains the 290 orders where customers paid more than the charge: instalment interest.

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
