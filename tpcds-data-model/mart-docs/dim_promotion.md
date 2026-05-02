# dim_promotion — Promotion Dimension

**Schema:** marts | **Rows:** 500 | **Primary Key:** `promo_sk`  
**Source:** `staging.promotion` → `raw.promotion`

---

## Purpose

Describes marketing promotions and the channels through which they were run.
All three fact tables reference this dimension, so you can compare the impact
of the same promotion across store, web, and catalog channels.

---

## Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `promo_sk` | INTEGER | NOT NULL | **Surrogate key.** Referenced as `ss_promo_sk`, `ws_promo_sk`, `cs_promo_sk` in all three fact tables. |
| `promo_id` | CHAR(16) | YES | **Natural key.** Source system promotion identifier. |
| `promo_name` | CHAR(50) | YES | Promotion name or description. |
| `purpose` | CHAR(15) | YES | Business goal: `Unknown`, `Cross-Sell`, `Retention`, `Awareness`. |
| `cost` | NUMERIC | YES | Total cost of running this promotion. |
| `response_target` | INTEGER | YES | Target response scope: 1 = all customers, higher = more selective targeting. |
| `channel_dmail` | CHAR(1) | YES | `Y` if run through direct mail. |
| `channel_email` | CHAR(1) | YES | `Y` if run through email. |
| `channel_catalog` | CHAR(1) | YES | `Y` if run through printed catalog. |
| `channel_tv` | CHAR(1) | YES | `Y` if run through television. |
| `channel_radio` | CHAR(1) | YES | `Y` if run through radio. |
| `channel_press` | CHAR(1) | YES | `Y` if run through press / print media. |
| `channel_event` | CHAR(1) | YES | `Y` if run through in-store event. |
| `channel_demo` | CHAR(1) | YES | `Y` if run through product demonstration. |
| `discount_active` | CHAR(1) | YES | `Y` if a price discount was active during this promotion. |

---

## Sample Queries

**Promoted vs non-promoted revenue:**
```sql
SELECT
    CASE WHEN f.ss_promo_sk IS NULL THEN 'No Promotion' ELSE 'Promotion' END AS promo_flag,
    SUM(ss_net_paid)   AS revenue,
    COUNT(*)           AS line_items
FROM marts.fact_store_sales f
GROUP BY promo_flag;
```

**Channel effectiveness:**
```sql
SELECT
    p.channel_tv,
    p.channel_email,
    COUNT(*)         AS transactions,
    SUM(ss_net_paid) AS revenue
FROM marts.fact_store_sales f
JOIN marts.dim_promotion p ON f.ss_promo_sk = p.promo_sk
GROUP BY p.channel_tv, p.channel_email
ORDER BY revenue DESC;
```

**ROI by promotion purpose:**
```sql
SELECT
    p.purpose,
    SUM(p.cost)       AS promo_cost,
    SUM(ss_net_paid)  AS revenue,
    ROUND(SUM(ss_net_paid) / NULLIF(SUM(p.cost), 0), 2) AS revenue_per_cost
FROM marts.fact_store_sales f
JOIN marts.dim_promotion p ON f.ss_promo_sk = p.promo_sk
GROUP BY p.purpose
ORDER BY revenue_per_cost DESC;
```

---

## Notes

- Always use `LEFT JOIN` when joining to `dim_promotion` — a NULL `*_promo_sk` in a fact table means a standard full-price sale with no promotion applied. A plain `JOIN` silently drops all non-promoted transactions.
- The channel columns are **not mutually exclusive** — one promotion can run across multiple channels simultaneously (e.g. `channel_tv = 'Y'` AND `channel_email = 'Y'`).
- `cost` is the total campaign cost, not a per-transaction cost. Divide by transaction count to get cost-per-transaction.
