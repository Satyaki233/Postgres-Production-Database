# staging.warehouse — Distribution Warehouses

**Rows:** 10 | **Source:** `raw.warehouse`

Distribution centre locations. Referenced by `inventory`, `web_sales`, and `catalog_sales`
via `*_warehouse_sk`. No marts dimension was created — query staging directly.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `w_warehouse_sk` | INTEGER | Surrogate key. Referenced as `inv_warehouse_sk`, `ws_warehouse_sk`, `cs_warehouse_sk`. |
| `w_warehouse_id` | CHAR(16) | Natural key. |
| `w_warehouse_name` | VARCHAR | Warehouse name. |
| `w_warehouse_sq_ft` | INTEGER | Warehouse floor area in square feet. |
| `w_street_number` | CHAR(10) | Street number. |
| `w_street_name` | VARCHAR | Street name. |
| `w_street_type` | CHAR(15) | Street type. |
| `w_suite_number` | CHAR(10) | Suite number. |
| `w_city` | VARCHAR | City. |
| `w_county` | VARCHAR | County. |
| `w_state` | CHAR(2) | State code. |
| `w_zip` | CHAR(10) | ZIP code. |
| `w_country` | VARCHAR | Country. |
| `w_gmt_offset` | NUMERIC | Timezone offset. |

## Sample Query
```sql
-- Inventory by warehouse
SELECT w.w_warehouse_name, w.w_state, SUM(inv_quantity_on_hand) AS total_stock
FROM staging.inventory i
JOIN staging.warehouse w ON i.inv_warehouse_sk = w.w_warehouse_sk
GROUP BY w.w_warehouse_name, w.w_state
ORDER BY total_stock DESC;
```
