import sqlite3
import random
from datetime import date, timedelta

random.seed(42)

DB_PATH = "/home/claude/irestore_practice/restoreyourself.db"

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

cur.executescript("""
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS marketing_spend;

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    signup_date TEXT NOT NULL,
    acquisition_channel TEXT NOT NULL,
    region TEXT NOT NULL
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date TEXT NOT NULL,
    product TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price REAL NOT NULL,
    discount_pct REAL NOT NULL,
    revenue REAL NOT NULL,
    unit_cost REAL NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE refunds (
    refund_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    refund_date TEXT NOT NULL,
    refund_amount REAL NOT NULL,
    reason TEXT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE marketing_spend (
    spend_id INTEGER PRIMARY KEY,
    spend_date TEXT NOT NULL,
    channel TEXT NOT NULL,
    spend REAL NOT NULL
);
""")

CHANNELS = ["Meta", "Google", "TikTok", "Affiliate", "Organic/Direct"]
CHANNEL_WEIGHTS = [0.38, 0.28, 0.14, 0.10, 0.10]
REGIONS = ["US", "UK", "CA", "AU", "EU"]
REGION_WEIGHTS = [0.62, 0.13, 0.10, 0.08, 0.07]

PRODUCTS = {
    "Hair Growth System (Device)": {"price": 495.0, "cost": 140.0, "repeat_prob": 0.05},
    "Scalp Serum": {"price": 59.0, "cost": 14.0, "repeat_prob": 0.35},
    "Replacement Cap Pads": {"price": 39.0, "cost": 9.0, "repeat_prob": 0.30},
    "Red Light Face Mask": {"price": 249.0, "cost": 75.0, "repeat_prob": 0.08},
}

START = date(2026, 1, 1)
END = date(2026, 7, 31)
DAYS = (END - START).days + 1

def daterange():
    for i in range(DAYS):
        yield START + timedelta(days=i)

spend_id = 1
base_daily_spend = {"Meta": 900, "Google": 650, "TikTok": 350, "Affiliate": 180, "Organic/Direct": 0}
spend_rows = []
for d in daterange():
    week_num = (d - START).days // 7
    trend = 1.0 + week_num * 0.01
    dow_factor = 1.15 if d.weekday() in (5, 6) else 1.0
    for ch, base in base_daily_spend.items():
        if base == 0:
            continue
        noise = random.uniform(0.85, 1.15)
        amt = round(base * trend * dow_factor * noise, 2)
        spend_rows.append((spend_id, d.isoformat(), ch, amt))
        spend_id += 1

cur.executemany(
    "INSERT INTO marketing_spend (spend_id, spend_date, channel, spend) VALUES (?,?,?,?)",
    spend_rows,
)

N_CUSTOMERS = 3200
customers = []
for cid in range(1, N_CUSTOMERS + 1):
    day_offset = int(random.triangular(0, DAYS - 1, DAYS - 1))
    d = START + timedelta(days=day_offset)
    if d.month == 2 and random.random() < 0.4:
        day_offset = max(0, day_offset - random.randint(10, 40))
        d = START + timedelta(days=day_offset)
    channel = random.choices(CHANNELS, weights=CHANNEL_WEIGHTS, k=1)[0]
    region = random.choices(REGIONS, weights=REGION_WEIGHTS, k=1)[0]
    customers.append((cid, d.isoformat(), channel, region))

cur.executemany(
    "INSERT INTO customers (customer_id, signup_date, acquisition_channel, region) VALUES (?,?,?,?)",
    customers,
)

order_id = 1
orders = []
DISCOUNT_CHOICES = [0.0, 0.0, 0.0, 0.10, 0.15, 0.20]

for cid, signup_str, channel, region in customers:
    signup_d = date.fromisoformat(signup_str)

    first_product = random.choices(
        list(PRODUCTS.keys()), weights=[0.55, 0.20, 0.10, 0.15], k=1
    )[0]
    spec = PRODUCTS[first_product]
    qty = 1
    discount = random.choices(DISCOUNT_CHOICES, weights=[50, 15, 10, 10, 10, 5])[0]
    unit_price = spec["price"]
    revenue = round(unit_price * qty * (1 - discount), 2)
    orders.append((order_id, cid, signup_d.isoformat(), first_product, qty, unit_price, discount, revenue, spec["cost"]))
    order_id += 1

    months_active = min(6, (END.year - signup_d.year) * 12 + (END.month - signup_d.month))
    for m in range(1, months_active + 1):
        base_repeat_chance = 0.14 if first_product == "Hair Growth System (Device)" else 0.22
        if random.random() < base_repeat_chance:
            repeat_product = random.choices(
                ["Scalp Serum", "Replacement Cap Pads", "Red Light Face Mask"],
                weights=[0.55, 0.30, 0.15],
                k=1,
            )[0]
            rspec = PRODUCTS[repeat_product]
            order_day_offset = random.randint(1, 28)
            try:
                mo = signup_d.month - 1 + m
                yr = signup_d.year + mo // 12
                mo = mo % 12 + 1
                order_d = date(yr, mo, min(order_day_offset, 28))
            except ValueError:
                continue
            if order_d > END:
                continue
            qty = random.choice([1, 1, 1, 2])
            discount = random.choices(DISCOUNT_CHOICES, weights=[60, 15, 10, 8, 5, 2])[0]
            revenue = round(rspec["price"] * qty * (1 - discount), 2)
            orders.append((order_id, cid, order_d.isoformat(), repeat_product, qty, rspec["price"], discount, revenue, rspec["cost"]))
            order_id += 1

cur.executemany(
    """INSERT INTO orders
       (order_id, customer_id, order_date, product, quantity, unit_price, discount_pct, revenue, unit_cost)
       VALUES (?,?,?,?,?,?,?,?,?)""",
    orders,
)

REFUND_RATES = {
    "Hair Growth System (Device)": 0.13,
    "Red Light Face Mask": 0.09,
    "Scalp Serum": 0.03,
    "Replacement Cap Pads": 0.02,
}
REFUND_REASONS = ["No results", "Changed mind", "Defective unit", "Shipping damage", "Ordered by mistake"]

refund_id = 1
refund_rows = []
for oid, cid, order_d, product, qty, unit_price, discount, revenue, unit_cost in [
    (o[0], o[1], date.fromisoformat(o[2]), o[3], o[4], o[5], o[6], o[7], o[8]) for o in orders
]:
    rate = REFUND_RATES.get(product, 0.03)
    if random.random() < rate:
        lag = random.randint(5, 35)
        rdate = order_d + timedelta(days=lag)
        if rdate > END:
            continue
        pct = random.choices([1.0, 0.5], weights=[85, 15])[0]
        amt = round(revenue * pct, 2)
        reason = random.choice(REFUND_REASONS)
        refund_rows.append((refund_id, oid, rdate.isoformat(), amt, reason))
        refund_id += 1

cur.executemany(
    "INSERT INTO refunds (refund_id, order_id, refund_date, refund_amount, reason) VALUES (?,?,?,?,?)",
    refund_rows,
)

conn.commit()
conn.close()
print("Done.")
