# staging.catalog_page — Printed Catalogue Pages

**Rows:** 12,000 | **Source:** `raw.catalog_page`

Each row represents a page in a printed product catalogue. Referenced by `catalog_sales`
and `catalog_returns` via `*_catalog_page_sk`. Useful for attributing sales to specific
catalogue editions and departments.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `cp_catalog_page_sk` | INTEGER | Surrogate key. Referenced as `cs_catalog_page_sk`, `cr_catalog_page_sk`. |
| `cp_catalog_page_id` | CHAR(16) | Natural key. |
| `cp_start_date_sk` | INTEGER | FK → `date_dim`. Date the catalogue became active. |
| `cp_end_date_sk` | INTEGER | FK → `date_dim`. Date the catalogue expired. |
| `cp_department` | VARCHAR | Department featured on this page (e.g. `children`, `sports`). |
| `cp_catalog_number` | INTEGER | The catalogue issue number this page belongs to. |
| `cp_catalog_page_number` | INTEGER | Page number within the catalogue. |
| `cp_description` | VARCHAR | Description of the page content. |
| `cp_type` | VARCHAR | Page type (e.g. `featured item`, `standard`). |

## Sample Query
```sql
-- Revenue attributed by catalogue department
SELECT cp.cp_department, SUM(cs_net_paid) AS revenue
FROM staging.catalog_sales cs
JOIN staging.catalog_page cp ON cs.cs_catalog_page_sk = cp.cp_catalog_page_sk
GROUP BY cp.cp_department
ORDER BY revenue DESC;
```
