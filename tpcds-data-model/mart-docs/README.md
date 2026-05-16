# TPC-DS Marts Data Model

The **marts layer** is the final, query-ready layer of the warehouse.
It follows the **Kimball star schema** pattern: fact tables in the centre,
dimension tables surrounding them.

---

## Star Schema Diagram

```
                          ┌─────────────┐
                          │  dim_date   │
                          │  73,049 rows│
                          └──────┬──────┘
                                 │ *_sold_date_sk
           ┌─────────────────────┼──────────────────────┐
           │                     │                      │
┌──────────▼────────┐  ┌─────────▼──────┐  ┌───────────▼──────────┐
│  fact_store_sales │  │ fact_web_sales  │  │  fact_catalog_sales  │
│    28.8M rows     │  │   7.2M rows     │  │     14.4M rows       │
└──────────┬────────┘  └─────────┬──────┘  └───────────┬──────────┘
           │                     │                      │
           └──── item_sk ────────┴──────────────────────┘
                                 │
                           ┌─────▼──────┐
                           │  dim_item  │
                           │  102,000   │
                           └────────────┘

           customer_sk ──► dim_customer  (500,000 rows)
           store_sk    ──► dim_store     (102 rows)      [store only]
           promo_sk    ──► dim_promotion (500 rows)
```

---

## Table Index

### Dimensions

| File                                 | Table                 | Rows    | Purpose                                          |
| ------------------------------------ | --------------------- | ------- | ------------------------------------------------ |
| [dim_date.md](dim_date.md)           | `marts.dim_date`      | 73,049  | Calendar — year, month, quarter, holiday flags   |
| [dim_customer.md](dim_customer.md)   | `marts.dim_customer`  | 500,000 | Customer + demographics + address (denormalised) |
| [dim_item.md](dim_item.md)           | `marts.dim_item`      | 102,000 | Product catalogue with brand, category, pricing  |
| [dim_store.md](dim_store.md)         | `marts.dim_store`     | 102     | Physical store locations                         |
| [dim_promotion.md](dim_promotion.md) | `marts.dim_promotion` | 500     | Marketing promotions and channels                |

### Facts

| File                                           | Table                      | Rows  | Size   | Purpose                     |
| ---------------------------------------------- | -------------------------- | ----- | ------ | --------------------------- |
| [fact_store_sales.md](fact_store_sales.md)     | `marts.fact_store_sales`   | 28.8M | 4.8 GB | In-store transactions       |
| [fact_catalog_sales.md](fact_catalog_sales.md) | `marts.fact_catalog_sales` | 14.4M | 2.9 GB | Phone / mail catalog orders |
| [fact_web_sales.md](fact_web_sales.md)         | `marts.fact_web_sales`     | 7.2M  | 1.4 GB | Online orders               |

---

## Key Concepts

**Surrogate key (`*_sk`)** — A system-generated integer that uniquely identifies a dimension row.
Has no business meaning. Used for all joins between facts and dimensions.

**Natural key (`*_id`)** — The original identifier from the source system.
Kept in the dimension for traceability but never used for warehouse joins.

**NULL foreign keys** — A NULL `ss_customer_sk` means an anonymous sale.
A NULL `ss_promo_sk` means no promotion was applied. Always use `LEFT JOIN`
on customer and promotion to avoid silently dropping these rows.

**Partitioning** — All three fact tables are `PARTITION BY RANGE (sold_date_sk)`.
All SF10 data lands in the `_default` partition. Named partitions can be added
later via pg_partman for partition pruning on date-range queries.

---

## Universal Join Template

```sql
SELECT
    d.full_date, d.year, d.month,
    i.category, i.brand,
    f.ss_quantity, f.ss_net_paid, f.ss_net_profit
FROM  marts.fact_store_sales  f
JOIN  marts.dim_date           d ON f.ss_sold_date_sk = d.date_sk
JOIN  marts.dim_item           i ON f.ss_item_sk      = i.item_sk
JOIN  marts.dim_store          s ON f.ss_store_sk     = s.store_sk
LEFT  JOIN marts.dim_customer  c ON f.ss_customer_sk  = c.customer_sk
LEFT  JOIN marts.dim_promotion p ON f.ss_promo_sk     = p.promo_sk;
```
