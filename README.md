# RestoreYourself: DTC Growth Analysis

A SQL project analyzing customer acquisition, retention, and profitability for
**RestoreYourself**, a fictional direct-to-consumer beauty/wellness brand selling
a hair-regrowth device plus repeat-purchase accessories (serum, replacement pads,
a red light face mask).

The dataset is synthetic - built to showcase the kind of growth analytics
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
<img width="1112" height="262" alt="image" src="https://github.com/user-attachments/assets/19506aaa-0c45-4544-bd49-6632113e4c50" />



**LTV by channel:** average revenue per customer varies by acquisition channel,
calculated from full order history per customer.
<img width="368" height="183" alt="image" src="https://github.com/user-attachments/assets/5ea909e1-974a-407b-b043-39943f5e61b9" />


**LTV:CAC ratio:**
no channel clears the commonly-cited healthy 3:1 threshold - ratios range from 1.75 (TikTok) to 2.13 (Affiliate). The core device is high-ticket but mostly a one-time purchase, and repeat-purchase probability on it is low, so most customers' lifetime revenue is dominated by their first order rather than compounding through repeat purchases. The takeaway: current CAC spend is only marginally justified by LTV across every channel - improving the ratio would require either higher repeat/accessory purchase rates or stronger unit economics on the device itself, not just cheaper acquisition.


<img width="606" height="178" alt="image" src="https://github.com/user-attachments/assets/307f7ea1-158d-45dd-a7ae-1467feeabef7" />



**Payback period:** Payback period: effectively immediate for every paid channel - average month-0 margin per customer already exceeds that channel's CAC (e.g. Affiliate: $200 month-0 margin vs. $159 CAC; Meta: $197 vs. $184). This is because the core device carries high margin on its own, so a single first purchase alone typically covers acquisition cost. Fast payback means acquisition risk is low across channels, but it's a separate finding from LTV:CAC — clearing CAC quickly doesn't mean a channel is profitable long-term, since that depends on repeat-purchase behavior, which stays weak (as shown by the LTV:CAC ratios above).

<img width="1265" height="1157" alt="image" src="https://github.com/user-attachments/assets/34dfe29d-5a6d-4cce-92ca-5d6bf5d5347b" />









**Assumptions & Limitations**

Signup = first purchase: this dataset treats account signup and first order as the same event. In real data these can differ, and CAC/cohort logic would need to anchor on whichever timestamp actually represents acquisition.
Refunds treated as pure loss: contribution margin assumes a refunded order loses both the revenue and the original unit cost, with no assumption of inventory recovery — conservative, since real recovery depends on whether the item is returned and resellable.
Refund-adjusted CAC excludes only first-order refunds: a customer who refunds a later order still counts as acquired — the adjustment targets whether the acquisition itself stuck.
Cohort retention is right-censored for the most recent 1-2 months — those cohorts haven't had time to show full repeat behavior yet.
Later-month payback averages are based on small sample sizes (e.g. Affiliate month 4 = 4 customers) and shouldn't be over-interpreted.
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
