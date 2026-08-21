# RestoreYourself: DTC Growth Analysis

A SQL project analyzing customer acquisition, retention, and profitability for
**RestoreYourself**, a fictional direct-to-consumer beauty/wellness brand selling
a hair-regrowth device plus repeat-purchase accessories (serum, replacement pads,
a red light face mask).

The dataset is synthetic — built to showcase the kind of growth analytics
questions a DTC e-commerce brand asks: which channels are actually worth the
spend, how well customers retain, and how long it takes for a channel to pay
for itself.

## Business questions

1. Which product lines drive the most revenue, and where are refunds concentrated?
2. What's the true cost to acquire a customer, by channel — and does that change
   once you account for customers who refund their first purchase?
3. How well do customers retain and repeat-purchase after their first order?
4. How long does it take for a channel's spend to pay for itself in margin?

## Findings

**Red Light Face Mask leads in terms of total revenue**



<img width="602" height="211" alt="image" src="https://github.com/user-attachments/assets/8c6e34ec-381c-4b55-af61-53b2370293af" />




**CAC by channel:** Affiliate is the cheapest channel to acquire customers
through and stays cheapest after adjusting for refunds. Meta and Google look
almost identical on raw CAC, but that's misleading - once refunded first-time
customers are excluded, Google is meaningfully cheaper than Meta. Meta has the
largest gap between raw and refund-adjusted CAC of any channel, meaning its
headline cost-per-customer understates how many of those customers don't
actually stick.

***Note: new_customer_count excludes all customers who refunded***
<img width="1132" height="182" alt="image" src="https://github.com/user-attachments/assets/cad0f6b2-0771-4419-ae0d-8a6ac6277cc6" />




**Retention:** Month-1 repeat-purchase rate holds fairly steady around 15–21%
across cohorts. The two most recent cohorts show artificially low retention in
later months - not a real decline, just incomplete data, since those customers
haven't had enough elapsed time to repeat yet (right-censoring).

**LTV by channel:** average revenue per customer varies by acquisition channel,
calculated from full order history per customer.

**Payback period:** in progress — cumulative contribution margin per customer,
by channel, compared against that channel's CAC to find the break-even month.

## Schema

- `customers` — customer_id, signup_date, acquisition_channel, region
- `orders` — order_id, customer_id, order_date, product, quantity, unit_price,
  discount_pct, revenue, unit_cost
- `refunds` — refund_id, order_id, refund_date, refund_amount, reason
- `marketing_spend` — spend_id, spend_date, channel, spend

## Files

- `generate_data.py` — generates the synthetic dataset
- `restoreyourself.db` — SQLite database
- `queries/` — SQL files, one per business question, with comments
- `customers.csv`, `orders.csv`, `refunds.csv`, `marketing_spend.csv` — raw data
