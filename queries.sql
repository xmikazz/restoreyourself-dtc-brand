-- RestoreYourself: DTC Growth Analytics
-- SQLite queries answering the business questions in README.md
-- Schema: customers, orders, refunds, marketing_spend


-- ============================================================
-- Q1. Which product lines drive the most revenue, and where
--     are refunds concentrated?
-- ============================================================
select
    o.product,
    sum(o.revenue) as total_revenue,
    sum(r.total_refunded) as refund_amount
from orders o
left join (
    select order_id, sum(refund_amount) as total_refunded
    from refunds
    group by order_id
) r on o.order_id = r.order_id
group by 1;
-- Finding: Red Light Face Mask leads in total revenue; the device
-- has the highest refund rate relative to its order volume.


-- ============================================================
-- Total marketing spend by channel, full period
-- ============================================================
select
    channel,
    sum(spend) as total_spend
from marketing_spend
group by 1;


-- ============================================================
-- Q2a. Basic CAC by acquisition channel
-- ============================================================
with b1 as (
    select
        acquisition_channel,
        count(*) as all_customer
    from customers
    group by 1
),
spend_by_channel as (
    select channel, sum(spend) as total_spend
    from marketing_spend
    group by 1
)
select
    b1.acquisition_channel as channel,
    total_spend,
    all_customer,
    round(total_spend / all_customer, 2) as basic_cac
from b1
left join spend_by_channel s on b1.acquisition_channel = s.channel;


-- ============================================================
-- Q2b. Refund-adjusted CAC by channel
-- Excludes customers who refunded their FIRST order from the
-- denominator, since they were never really "retained".
-- ============================================================
with b1 as (
    select acquisition_channel, count(*) as all_customer
    from customers
    group by 1
),
no_refund_first_order as (
    select o.customer_id
    from orders o
    left join refunds r on o.order_id = r.order_id
    where r.order_id is null
    group by o.customer_id
),
t3 as (
    select c.acquisition_channel, count(*) as new_customer_count
    from no_refund_first_order n
    left join customers c on n.customer_id = c.customer_id
    group by 1
),
spend_final as (
    select channel, sum(spend) as total_spend
    from marketing_spend
    group by 1
)
select
    b1.acquisition_channel as channel,
    total_spend,
    all_customer,
    new_customer_count,
    round(total_spend / all_customer, 2) as basic_cac,
    round(total_spend / new_customer_count, 2) as new_cac,
    round((total_spend / new_customer_count) - (total_spend / all_customer), 2) as diff
from b1
left join spend_final s on b1.acquisition_channel = s.channel
left join t3 on b1.acquisition_channel = t3.acquisition_channel;
-- Finding: Affiliate cheapest either way. Meta and Google look
-- nearly tied on raw CAC, but Google is meaningfully cheaper once
-- refund-adjusted -- Meta has the largest raw-vs-adjusted gap.


-- ============================================================
-- Q3a. Monthly cohort retention: of customers who signed up in a
--      given month, what % placed another order in month 1, 2?
-- Note: signup_date = first purchase date in this dataset.
-- ============================================================
with base as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        c.signup_date,
        (strftime('%Y', o.order_date) - strftime('%Y', c.signup_date)) * 12
            + (strftime('%m', o.order_date) - strftime('%m', c.signup_date))
            as months_since_signup,
        strftime('%Y-%m', c.signup_date) as cohort_month
    from orders o
    left join customers c on o.customer_id = c.customer_id
),
cohort_size as (
    select cohort_month, count(distinct customer_id) as cohort_size
    from base
    group by 1
),
repeat_m1 as (
    select cohort_month, count(distinct customer_id) as repeat_month1
    from base
    where months_since_signup = 1
    group by 1
),
repeat_m2 as (
    select cohort_month, count(distinct customer_id) as repeat_month2
    from base
    where months_since_signup = 2
    group by 1
)
select
    cs.cohort_month,
    cs.cohort_size,
    repeat_month1,
    repeat_month2,
    round(1.0 * coalesce(repeat_month1, 0) / cohort_size, 3) as retention_m1,
    round(1.0 * coalesce(repeat_month2, 0) / cohort_size, 3) as retention_m2
from cohort_size cs
left join repeat_m1 r1 on cs.cohort_month = r1.cohort_month
left join repeat_m2 r2 on cs.cohort_month = r2.cohort_month;
-- Finding: month-1 retention holds ~15-21% across cohorts. The
-- two most recent cohorts show artificially low later-month
-- retention -- right-censoring, not a real decline.


-- ============================================================
-- Q3b. LTV per channel: average total revenue per customer
-- ============================================================
with customer_revenue as (
    select customer_id, sum(revenue) as revenue_per_customer
    from orders
    group by 1
)
select
    c.acquisition_channel as channel,
    avg(revenue_per_customer) as avg_ltv
from customer_revenue cr
left join customers c on cr.customer_id = c.customer_id
group by 1;


-- ============================================================
-- Q4. LTV:CAC ratio by channel
-- ============================================================
with cac_base as (
    select acquisition_channel, count(*) as all_customer
    from customers
    group by 1
),
no_refund_first_order as (
    select o.customer_id
    from orders o
    left join refunds r on o.order_id = r.order_id
    where r.order_id is null
    group by o.customer_id
),
new_cac_counts as (
    select c.acquisition_channel, count(*) as new_customer_count
    from no_refund_first_order n
    left join customers c on n.customer_id = c.customer_id
    group by 1
),
spend_by_channel as (
    select channel, sum(spend) as total_spend
    from marketing_spend
    group by 1
),
cac_final as (
    select
        cb.acquisition_channel as channel,
        total_spend / new_customer_count as new_cac
    from cac_base cb
    left join spend_by_channel s on cb.acquisition_channel = s.channel
    left join new_cac_counts n on cb.acquisition_channel = n.acquisition_channel
),
customer_revenue as (
    select customer_id, sum(revenue) as revenue_per_customer
    from orders
    group by 1
),
ltv_final as (
    select c.acquisition_channel as channel, avg(revenue_per_customer) as avg_ltv
    from customer_revenue cr
    left join customers c on cr.customer_id = c.customer_id
    group by 1
)
select
    l.channel,
    avg_ltv,
    new_cac,
    round(avg_ltv / new_cac, 2) as ltv_cac_ratio
from ltv_final l
left join cac_final c on l.channel = c.channel;
-- Finding: no channel clears the commonly-cited healthy 3:1
-- threshold. Range: 1.75 (TikTok) to 2.13 (Affiliate). The
-- device is high-ticket but mostly one-time, so most lifetime
-- revenue comes from the first order rather than compounding
-- through repeat purchases.


-- ============================================================
-- Q5. Payback period: average cumulative margin per customer,
--     by channel and months since signup, vs. that channel's CAC
-- Assumption: a refunded order loses both revenue and unit cost
-- (no assumption of inventory recovery) -- conservative but
-- realistic given the dataset has no return/restock flag.
-- ============================================================
with base as (
    select
        o.order_id,
        o.customer_id,
        c.acquisition_channel,
        o.order_date,
        o.revenue,
        o.unit_cost,
        r.refund_amount,
        (o.revenue - o.unit_cost - coalesce(r.refund_amount, 0)) as margin,
        (strftime('%Y', o.order_date) - strftime('%Y', c.signup_date)) * 12
            + (strftime('%m', o.order_date) - strftime('%m', c.signup_date))
            as months_since_signup
    from orders o
    left join refunds r on o.order_id = r.order_id
    left join customers c on o.customer_id = c.customer_id
)
select
    acquisition_channel,
    months_since_signup,
    count(distinct customer_id) as unique_customers,
    sum(margin) as monthly_margin,
    sum(margin) / count(distinct customer_id) as average_margin
from base
group by 1, 2
order by 1, 2;
-- Finding: payback is effectively immediate for every paid
-- channel -- average month-0 margin per customer already exceeds
-- that channel's CAC (e.g. Affiliate: ~$200 month-0 margin vs.
-- ~$159 CAC). The device carries enough margin on its own to
-- cover acquisition cost in a single sale. This is a separate
-- finding from LTV:CAC: fast payback means low acquisition risk,
-- but doesn't mean a channel is profitable long-term, since that
-- depends on repeat-purchase behavior, which stays weak. Later
-- months in this table have small sample sizes and are noisy.
