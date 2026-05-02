# dim_customer — Customer Dimension

**Schema:** marts | **Rows:** 500,000 | **Primary Key:** `customer_sk`  
**Source:** `staging.customer` + `staging.customer_demographics` + `staging.customer_address`

---

## Purpose

A **denormalised** dimension that merges three raw tables into one wide row per customer.
Analysts answer "who bought this?" with a single join — no chaining through multiple tables.

This is the Kimball pattern: flatten the snowflake into a star at query time.

---

## Columns

| Column              | Type    | Nullable | Description                                                                                                                                                   |
| ------------------- | ------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `customer_sk`       | INTEGER | NOT NULL | **Surrogate key.** Referenced as `ss_customer_sk`, `ws_bill_customer_sk`, `ws_ship_customer_sk`, `cs_bill_customer_sk`, `cs_ship_customer_sk` in fact tables. |
| `customer_id`       | TEXT    | YES      | **Natural key.** 16-char ID from the source system. Kept for traceability, not for joins.                                                                     |
| `first_name`        | TEXT    | YES      | Customer first name.                                                                                                                                          |
| `last_name`         | TEXT    | YES      | Customer last name.                                                                                                                                           |
| `salutation`        | TEXT    | YES      | Title: `Mr.`, `Mrs.`, `Dr.`, `Miss`, `Sir` …                                                                                                                  |
| `email`             | TEXT    | YES      | Email address.                                                                                                                                                |
| `preferred_flag`    | CHAR(1) | YES      | `Y` = loyalty / preferred member. `N` = standard.                                                                                                             |
| `birth_year`        | INTEGER | YES      | Year of birth. Use for age-band segmentation.                                                                                                                 |
| `birth_country`     | TEXT    | YES      | Country of birth.                                                                                                                                             |
| `gender`            | CHAR(1) | YES      | `M` or `F`. Sourced from `customer_demographics`.                                                                                                             |
| `marital_status`    | CHAR(1) | YES      | `S` Single, `M` Married, `D` Divorced, `W` Widowed.                                                                                                           |
| `education_status`  | TEXT    | YES      | Highest education level: `Unknown`, `2 yr Degree`, `4 yr Degree`, `College`, `Advanced Degree`, `Primary`, `Secondary`.                                       |
| `purchase_estimate` | INTEGER | YES      | Estimated annual spend band in dollars (0–10,000 in steps of 500).                                                                                            |
| `credit_rating`     | TEXT    | YES      | Credit band: `Good`, `High Risk`, `Low Risk`, `Unknown`.                                                                                                      |
| `dep_count`         | INTEGER | YES      | Number of financial dependants.                                                                                                                               |
| `city`              | TEXT    | YES      | City from the customer's current mailing address.                                                                                                             |
| `state`             | TEXT    | YES      | State / province code from the current address.                                                                                                               |
| `zip`               | TEXT    | YES      | ZIP / postal code.                                                                                                                                            |
| `country`           | TEXT    | YES      | Country of residence.                                                                                                                                         |
| `gmt_offset`        | NUMERIC | YES      | GMT timezone offset of the customer's address.                                                                                                                |
| `cd_demo_sk`        | INTEGER | YES      | FK back to `raw.customer_demographics`. Kept for debugging; not needed for analysis.                                                                          |
| `ca_address_sk`     | INTEGER | YES      | FK back to `raw.customer_address`. Kept for debugging; not needed for analysis.                                                                               |

---

## Sample Queries

**Revenue by education level:**

```sql
SELECT c.education_status, SUM(ss_net_paid) AS revenue, COUNT(*) AS orders
FROM marts.fact_store_sales f
LEFT JOIN marts.dim_customer c ON f.ss_customer_sk = c.customer_sk
GROUP BY c.education_status
ORDER BY revenue DESC;
```

**Top states by customer count:**

```sql
SELECT state, COUNT(*) AS customers
FROM marts.dim_customer
GROUP BY state
ORDER BY customers DESC
LIMIT 10;
```

**Preferred vs non-preferred revenue:**

```sql
SELECT
    COALESCE(c.preferred_flag, 'N') AS preferred,
    SUM(ss_net_paid)                 AS revenue
FROM marts.fact_store_sales f
LEFT JOIN marts.dim_customer c ON f.ss_customer_sk = c.customer_sk
GROUP BY preferred;
```

---

## Notes

- Always use `LEFT JOIN` when joining to `dim_customer` from fact tables — a NULL `*_customer_sk` means an anonymous (guest) transaction and is valid data. A plain `JOIN` silently drops those rows.
- `web_sales` and `catalog_sales` have **two** customer keys: `bill_customer_sk` (who paid) and `ship_customer_sk` (who received). They can differ for gift orders.
- Demographics reflect the customer's **current** snapshot. TPC-DS does not track demographic history — there is no SCD Type 2 on this dimension.
