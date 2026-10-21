# Memo: late deliveries are costing us reviews

**To:** Head of Operations, Olist (fictional)
**From:** Ayoola Fadare, Data Analyst
**Date:** 21 October 2026
**Data:** 96,203 delivered orders, January 2017 – August 2018 ([dashboard](../README.md#dashboard), [full analysis](../README.md#findings))

## The headline

**6.8% of orders arrive late, and lateness is the biggest driver of bad reviews we can see.** Late orders average **2.3 stars against 4.3** for on-time orders, and **over half (53.7%) get a 1-star review**. Each extra day makes it worse: 1–3 days late costs a full star, and 8+ days late drops the average to 1.7. These are associations rather than proof of cause, but the steady drop with every extra day makes delivery reliability the clearest lever on customer satisfaction.

## Three recommendations

**1. Fix the northeast and Rio de Janeiro first.**
The northeast is late on **12.7%** of orders, twice the southeast (6.1%), and Alagoas reaches **21.4%**. Rio is the biggest problem by volume: it has **12.8% of orders but 23.3% of all late deliveries**. Bringing Rio's late rate down to São Paulo's (4.5%) would have meant about **940 fewer late orders**.
*Action:* review carrier performance and delivery-date estimates for Rio and the northeast. Where delivery can't be faster, set longer, more realistic estimates; the remote north already shows that slow deliveries can still be on time.

**2. Plan for peaks and watch carriers monthly.**
Late deliveries came in two waves. **Black Friday (Nov 2017)** pushed orders up 63% and the late rate to **12.4%**. In **Feb–Mar 2018**, the late rate hit **14–19% with no rise in volume**, because deliveries simply took longer (16–17 days). The data doesn't show why.
*Action:* agree extra carrier capacity before Black Friday, and use the dashboard's monthly late rate as an early-warning check by region, so a slowdown like Q1 2018 is caught in weeks, not months.

**3. Start a seller quality review with the largest sellers.**
Two of our top 5 sellers by revenue rank **376th and 411th of 424** on reviews (3.85 and 3.50 stars) across about 2,750 orders. Their late rates (9–10%) are similar to well-rated sellers, so the problem is likely product or service quality rather than delivery.
*Action:* review complaints with these two sellers first, then add review score and late rate to a regular seller scorecard.

## Beyond operations

Only **2.1%** of customers genuinely come back for a second order, typically about 77 days later. A follow-up 30–60 days after the first order is worth testing with the commercial team. Better delivery should also help, since poor experiences are unlikely to bring customers back.

## Limits of this analysis

The dataset has no cost, margin or carrier data, so these recommendations show where to act but not the cost of acting. Review scores and lateness are linked, but other factors, such as product type or destination, may also contribute.
