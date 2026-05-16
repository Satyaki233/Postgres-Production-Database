# TPC-DS Staging Layer

The **staging schema** is the second layer of the three-layer warehouse architecture.

```
raw  →  staging  →  marts
```

---

## What Staging Does

Staging receives data from the `raw` schema and applies lightweight cleaning:

- **TRIM()** on all string/character columns — removes leading and trailing whitespace left by dsdgen
- **NULLIF** on address and name fields — converts empty strings `''` to proper `NULL`
- **Filters** rows with NULL mandatory keys (e.g. rows with no `item_sk` in sales tables)
- **No aggregations, no joins, no business logic** — staging is still one row = one source row

Staging does **not** rename columns, change data types, or denormalise tables.
All column names are identical to raw (`ss_sold_date_sk`, `i_item_sk`, etc.).

---

## What Staging Is NOT

Staging is not the analysis layer. Use **marts** for reporting queries:

- `marts.dim_*` — clean, renamed, denormalised dimensions
- `marts.fact_*` — partitioned facts with indexes

Use staging when you need columns that weren't promoted to marts
(e.g. `cs_ship_date_sk`, `ss_cdemo_sk`, full inventory detail).

---

## Table Index

### Dimension / Reference Tables

| File                                                   | Table                            | Rows      | Description                      |
| ------------------------------------------------------ | -------------------------------- | --------- | -------------------------------- |
| [date_dim.md](date_dim.md)                             | `staging.date_dim`               | 73,049    | Full calendar with 28 attributes |
| [time_dim.md](time_dim.md)                             | `staging.time_dim`               | 86,400    | Time of day (one row per second) |
| [customer.md](customer.md)                             | `staging.customer`               | 500,000   | Customer master                  |
| [customer_demographics.md](customer_demographics.md)   | `staging.customer_demographics`  | 1,920,800 | Demographic snapshots            |
| [customer_address.md](customer_address.md)             | `staging.customer_address`       | 250,000   | Mailing addresses                |
| [item.md](item.md)                                     | `staging.item`                   | 102,000   | Product catalogue                |
| [store.md](store.md)                                   | `staging.store`                  | 102       | Physical store locations         |
| [promotion.md](promotion.md)                           | `staging.promotion`              | 500       | Marketing promotions             |
| [household_demographics.md](household_demographics.md) | `staging.household_demographics` | 7,200     | Household income / vehicle data  |
| [income_band.md](income_band.md)                       | `staging.income_band`            | 20        | Income range lookup              |
| [web_site.md](web_site.md)                             | `staging.web_site`               | 42        | Web domains                      |
| [web_page.md](web_page.md)                             | `staging.web_page`               | 200       | Individual web pages             |
| [warehouse.md](warehouse.md)                           | `staging.warehouse`              | 10        | Distribution warehouses          |
| [ship_mode.md](ship_mode.md)                           | `staging.ship_mode`              | 20        | Shipping method lookup           |
| [reason.md](reason.md)                                 | `staging.reason`                 | 45        | Return reason codes              |
| [call_center.md](call_center.md)                       | `staging.call_center`            | 24        | Call centre locations            |
| [catalog_page.md](catalog_page.md)                     | `staging.catalog_page`           | 12,000    | Printed catalogue pages          |

### Fact / Transaction Tables

| File                                     | Table                     | Rows        | Description               |
| ---------------------------------------- | ------------------------- | ----------- | ------------------------- |
| [store_sales.md](store_sales.md)         | `staging.store_sales`     | 28,800,991  | In-store sales line items |
| [catalog_sales.md](catalog_sales.md)     | `staging.catalog_sales`   | 14,401,261  | Catalog order line items  |
| [web_sales.md](web_sales.md)             | `staging.web_sales`       | 7,197,566   | Web order line items      |
| [store_returns.md](store_returns.md)     | `staging.store_returns`   | 2,875,357   | In-store return events    |
| [catalog_returns.md](catalog_returns.md) | `staging.catalog_returns` | 1,439,749   | Catalog return events     |
| [web_returns.md](web_returns.md)         | `staging.web_returns`     | 719,217     | Web return events         |
| [inventory.md](inventory.md)             | `staging.inventory`       | 133,110,000 | Daily inventory snapshots |

---

## Relationship Map

```
customer_demographics ──┐
customer_address      ──┼──► customer ──► store_sales / web_sales / catalog_sales
household_demographics──┘                         │
income_band ──► household_demographics            ▼
                                           store_returns / web_returns / catalog_returns
date_dim ──► all sales and returns

item ──► store_sales / web_sales / catalog_sales / inventory

store ──► store_sales / store_returns
web_site / web_page ──► web_sales / web_returns
call_center / catalog_page ──► catalog_sales / catalog_returns

warehouse ──► inventory / web_sales / catalog_sales
ship_mode ──► web_sales / catalog_sales / catalog_returns
reason ──► store_returns / catalog_returns / web_returns
promotion ──► store_sales / web_sales / catalog_sales
```

---

## Key Differences: Staging vs Raw vs Marts

|                 | raw          | staging                       | marts                              |
| --------------- | ------------ | ----------------------------- | ---------------------------------- |
| Column names    | TPC-DS spec  | Same as raw                   | Renamed (human-friendly)           |
| String cleaning | None         | TRIM + NULLIF                 | Inherited from staging             |
| Denormalisation | None         | None                          | Yes (dim_customer merges 3 tables) |
| Indexes         | None         | None                          | Yes (on FK columns)                |
| Partitioning    | None         | None                          | Yes (facts by date_sk)             |
| Best used for   | Data loading | Debugging, full column access | Analytics, BI tools                |
