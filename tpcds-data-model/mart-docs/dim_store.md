# dim_store — Store Dimension

**Schema:** marts | **Rows:** 102 | **Primary Key:** `store_sk`  
**Source:** `staging.store` → `raw.store`

---

## Purpose

Describes physical retail store locations. Only `fact_store_sales` references this dimension —
web and catalog orders have no physical store.

---

## Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `store_sk` | INTEGER | NOT NULL | **Surrogate key.** Referenced as `ss_store_sk` in `fact_store_sales`. |
| `store_id` | CHAR(16) | YES | **Natural key.** Source system store identifier. |
| `store_name` | VARCHAR | YES | Store name (e.g. `able estern`). |
| `employees` | INTEGER | YES | Number of employees at this location. |
| `floor_space` | INTEGER | YES | Floor space in square feet. |
| `hours` | CHAR(20) | YES | Operating hours (e.g. `8AM-4PM`, `8AM-12AM`). |
| `manager` | VARCHAR | YES | Name of the store manager. |
| `market_id` | INTEGER | YES | Regional market group identifier. |
| `market_desc` | VARCHAR | YES | Description of the regional market. |
| `city` | VARCHAR | YES | City where the store is located. |
| `state` | CHAR(2) | YES | US state code. |
| `zip` | CHAR(10) | YES | ZIP code. |
| `country` | VARCHAR | YES | Country. |
| `gmt_offset` | NUMERIC | YES | Timezone offset from GMT. |
| `tax_rate` | NUMERIC | YES | Local sales tax rate applied at this store. |
| `valid_from` | DATE | YES | **SCD Type 2:** start date of this store record version. |
| `valid_to` | DATE | YES | **SCD Type 2:** end date. NULL = currently active. |

---

## Sample Queries

**Revenue by state:**
```sql
SELECT s.state, SUM(ss_net_paid) AS revenue, COUNT(DISTINCT ss_ticket_number) AS transactions
FROM marts.fact_store_sales f
JOIN marts.dim_store s ON f.ss_store_sk = s.store_sk
GROUP BY s.state
ORDER BY revenue DESC;
```

**Large-floor-space stores vs small:**
```sql
SELECT
    CASE WHEN s.floor_space > 200000 THEN 'large' ELSE 'small' END AS store_size,
    SUM(ss_net_paid) AS revenue
FROM marts.fact_store_sales f
JOIN marts.dim_store s ON f.ss_store_sk = s.store_sk
GROUP BY store_size;
```

---

## Notes

- `valid_from` / `valid_to` are **SCD Type 2** columns. A store gets a new `store_sk` if its attributes change (new manager, tax rate change). Old sales preserve the store's state at the time of the transaction.
- `tax_rate` is the store's local rate. Actual tax collected per transaction is `ss_ext_tax` in `fact_store_sales`.
- Only 102 stores in SF10 — this is a very small dimension and will always fit in memory.
