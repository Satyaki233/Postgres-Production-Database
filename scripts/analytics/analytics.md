# Data Warehouse Analytical Queries

**File:** `scripts/analytics/warehouse_queries.sql`  
**Schema:** `marts`  
**Dataset:** TPC-DS SF10 (~50M rows across store, web, and catalog channels, years 1998–2002)

---

## Purpose

These queries validate that the data warehouse is working correctly end-to-end and demonstrate the kind of business intelligence the marts layer is designed to support. Each query joins across the star schema — fact tables to dimension tables — to answer a concrete business question. They also exercise partitioned fact tables, window functions, and cross-channel UNION patterns.

---

## Query Reference

---

### Q1 — Annual Revenue by Sales Channel

**What it does:**  
Aggregates `net_paid` (revenue received from customers) for all three sales channels — store, web, and catalog — broken down by year.

**Why it matters:**  
This is the top-level executive view. It tells you which channel is growing, which is shrinking, and what the total business looks like year over year. It's the first sanity check that all three fact tables are loaded and joined correctly to `dim_date`.

**Key columns:**
| Column | Meaning |
|---|---|
| `store_net_paid_M` | Total store revenue in millions |
| `web_net_paid_M` | Total web revenue in millions |
| `catalog_net_paid_M` | Total catalog revenue in millions |
| `total_net_paid_M` | Combined revenue across all channels |

**What to look for:** Roughly equal year-over-year totals (TPC-DS data is synthetic and evenly distributed). If one channel shows 0, that fact table didn't load.

---

### Q2 — Top 10 Product Categories by Net Profit (Store Channel)

**What it does:**  
Groups all store sales by item category, sums up revenue and profit, and ranks the top 10 by `net_profit_M`.

**Why it matters:**  
Revenue alone is misleading — a high-revenue category can be unprofitable if wholesale cost and discounts eat the margin. This query surfaces which categories actually make money. A retailer would use this to decide where to expand inventory or cut underperformers.

**Key columns:**
| Column | Meaning |
|---|---|
| `net_paid_M` | Total revenue collected (after discounts, before tax) |
| `net_profit_M` | Revenue minus wholesale cost, tax, and coupons |
| `profit_margin_pct` | `net_profit / net_paid × 100` — what % of revenue is kept as profit |

**What to look for:** Categories with high revenue but low (or negative) margins indicate over-discounting or high wholesale cost.

---

### Q3 — Store Performance Ranking

**What it does:**  
Ranks every physical store by total net profit using a `RANK()` window function. Also shows profit margin and average transaction value so you can distinguish high-volume stores from high-efficiency ones.

**Why it matters:**  
Two stores can have the same revenue but very different profitability. A store with a high average transaction value but low volume might be more valuable than a high-volume, low-margin one. This query gives operations management a full picture of each store's health.

**Key columns:**
| Column | Meaning |
|---|---|
| `net_profit_M` | Total profit for the store across all years |
| `profit_margin_pct` | Profit as a % of revenue |
| `avg_txn_value` | Average dollars per transaction ticket |
| `profit_rank` | 1 = most profitable store |

**What to look for:** Stores with low rank but high `avg_txn_value` are high-quality but low-traffic — potential growth candidates. Stores with negative margin are losing money.

---

### Q4 — Customer Segments by Credit Rating and Gender

**What it does:**  
Joins store sales to the denormalized `dim_customer` (which already includes demographic data) and groups revenue by credit rating × gender. Shows unique customer count, total spend, and average spend per transaction.

**Why it matters:**  
This is a demographic cut of the customer base. It answers: which customer segment spends the most per visit? Credit rating is a proxy for financial capacity; combining it with gender reveals whether high-rated women or men drive more revenue — useful for targeted marketing.

**Key columns:**
| Column | Meaning |
|---|---|
| `unique_customers` | Distinct customers in this segment |
| `net_paid_M` | Total revenue from this segment |
| `avg_spend_per_txn` | How much the average person in this segment spends per visit |

**What to look for:** Segments with high `avg_spend_per_txn` but low `unique_customers` are high-value but under-penetrated — a targeting opportunity.

---

### Q5 — Promotion Effectiveness

**What it does:**  
For each promotion, calculates total revenue generated, total discounts given, the promotion's declared cost, and a `revenue_per_promo_dollar` ratio — how much revenue was produced for every dollar spent on the promotion.

A baseline average transaction value (from non-promoted sales) is computed as a CTE and carried alongside for reference.

**Why it matters:**  
Not all promotions are worth their cost. A promotion that generates $1M in revenue but cost $800K to run is far less efficient than one that cost $50K. This query lets the marketing team rank promotions by ROI and cut the ones that aren't pulling their weight.

**Key columns:**
| Column | Meaning |
|---|---|
| `net_paid_M` | Revenue generated during this promotion |
| `total_discount` | Total discount dollars given away |
| `promo_cost` | Declared cost of running the promotion |
| `revenue_per_promo_dollar` | Revenue ÷ promo cost — higher is better |

**What to look for:** Promotions with low `revenue_per_promo_dollar` are subsidizing customers who may have bought anyway. Promotions with high discount but low lift indicate customers taking the deal without incremental spend.

---

### Q6 — Monthly Sales Trend with 3-Month Moving Average

**What it does:**  
Computes monthly store revenue from 1998–2002, then overlays a 3-month rolling average using a window function (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`). The moving average smooths out month-to-month noise to make seasonal trends visible.

**Why it matters:**  
Raw monthly revenue is noisy. The moving average reveals the underlying trend — are we climbing into Q4, or is a specific month always a valley? This is the foundation of any time-series dashboard.

**Key columns:**
| Column | Meaning |
|---|---|
| `net_paid_M` | Actual revenue for that month |
| `moving_avg_3m` | Average of the current month + prior 2 months |

**What to look for:** Months where actual revenue spikes well above the moving average indicate seasonality or a one-time event. A persistent gap means a structural trend shift.

---

### Q7 — Year-over-Year Revenue Growth by Channel

**What it does:**  
Uses `LAG()` to compare each year's revenue to the prior year's revenue for all three channels, computing a `%` growth rate without a self-join. The first year (1998) will show `NULL` for YoY since there is no prior year to compare against.

**Why it matters:**  
Absolute revenue numbers tell you size; YoY growth tells you direction and momentum. If web is growing at 8% while store is flat at 0.2%, the business should probably be shifting investment toward web infrastructure.

**Key columns:**
| Column | Meaning |
|---|---|
| `store_yoy_pct` | Store revenue growth vs prior year (%) |
| `web_yoy_pct` | Web revenue growth vs prior year (%) |
| `catalog_yoy_pct` | Catalog revenue growth vs prior year (%) |

**What to look for:** In TPC-DS synthetic data these will be near-zero (data is uniformly distributed). In real data, diverging growth rates signal channel shifts worth investigating.

---

### Q8 — Holiday Lift Analysis

**What it does:**  
Classifies every sales day into one of three buckets — Holiday, Weekend, or Regular weekday — using the `is_holiday` and `is_weekend` flags on `dim_date`. Then computes average daily revenue for each bucket to measure whether holidays or weekends drive a meaningful revenue lift.

**Why it matters:**  
Retailers allocate staff, inventory, and marketing spend around holidays and weekends. If holidays don't actually produce higher average daily revenue, those resources are being misallocated. This query quantifies the lift (or lack of it).

**Key columns:**
| Column | Meaning |
|---|---|
| `days` | Number of distinct days in this bucket |
| `avg_daily_revenue_K` | Average revenue per day (in thousands) |
| `avg_txn_value` | Average dollars per transaction on these days |

**What to look for:** If holiday `avg_daily_revenue_K` is only slightly above regular weekdays, the holiday premium may not justify the extra staffing cost.

---

### Q9 — Top 10 States by Net Profit

**What it does:**  
Joins store sales to `dim_customer` (which has the customer's state from their address) and aggregates revenue and profit by state. Shows unique customer count alongside financials to distinguish high-population states from genuinely high-value markets.

**Why it matters:**  
Geographic concentration analysis tells leadership where the business actually lives. If 40% of profit comes from 3 states, supply chain, store expansion, and marketing should be concentrated there — or the business needs to diversify its geographic risk.

**Key columns:**
| Column | Meaning |
|---|---|
| `unique_customers` | Distinct customers from this state who made a purchase |
| `net_profit_M` | Total profit attributable to customers from this state |
| `profit_margin_pct` | Whether this state's customers are more/less profitable than average |

**What to look for:** States with high `unique_customers` but lower-than-average `profit_margin_pct` may have a discount or return problem in that region.

---

### Q10 — Brand Profitability Across All Channels

**What it does:**  
UNIONs all three fact tables (store, web, catalog) and joins to `dim_item` to get brand and category. Aggregates total cross-channel revenue and profit per brand, then ranks by total profit.

**Why it matters:**  
A brand might dominate in-store but underperform online. By combining all channels into one view, you see the brand's true footprint in the business. This is the query a category manager would run before a vendor negotiation — it shows exactly how much profit each brand contributes across the entire operation.

**Key columns:**
| Column | Meaning |
|---|---|
| `total_revenue_M` | Combined revenue from all 3 channels for this brand |
| `total_profit_M` | Combined profit — the number vendors care about most |
| `profit_margin_pct` | Whether this brand is more or less profitable than average |

**What to look for:** Brands with high revenue but below-average margin may be carrying excessive promotional costs or wholesale pricing that needs renegotiation.

---
## Schema Cheat Sheet

```
fact_store_sales   ──┬── dim_date      (ss_sold_date_sk  → date_sk)
                     ├── dim_item      (ss_item_sk       → item_sk)
                     ├── dim_customer  (ss_customer_sk   → customer_sk)
                     ├── dim_store     (ss_store_sk      → store_sk)
                     └── dim_promotion (ss_promo_sk      → promo_sk)

fact_web_sales     ──┬── dim_date      (ws_sold_date_sk  → date_sk)
                     ├── dim_item      (ws_item_sk       → item_sk)
                     ├── dim_customer  (ws_bill_customer_sk → customer_sk)
                     └── dim_promotion (ws_promo_sk      → promo_sk)

fact_catalog_sales ──┬── dim_date      (cs_sold_date_sk  → date_sk)
                     ├── dim_item      (cs_item_sk       → item_sk)
                     ├── dim_customer  (cs_bill_customer_sk → customer_sk)
                     └── dim_promotion (cs_promo_sk      → promo_sk)
```
