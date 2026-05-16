# staging.inventory — Daily Inventory Snapshots

**Rows:** 133,110,000 | **Source:** `raw.inventory`

The largest table in the warehouse. Records the quantity on hand for every item
at every warehouse on every date in the TPC-DS calendar. This is a **snapshot fact table**:
unlike sales tables (which record events), inventory records a state at a point in time.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `inv_date_sk` | INTEGER | FK → `date_dim`. The date of this snapshot. |
| `inv_item_sk` | INTEGER | FK → `item`. The item being tracked. |
| `inv_warehouse_sk` | INTEGER | FK → `warehouse`. The warehouse holding the stock. |
| `inv_quantity_on_hand` | INTEGER | Number of units on hand at this warehouse on this date. |

## Grain
One row = one item × one warehouse × one date.

At SF10: 102,000 items × 10 warehouses × ~1,834 dates ≈ 133M rows.

## Snapshot vs Transaction Facts

| | Sales tables | Inventory |
|---|---|---|
| Records | An event that happened | A state at a point in time |
| Additive? | Yes — SUM makes sense | Partially — SUM across warehouses is valid, SUM across dates is NOT |
| Example | "28M sales occurred" | "On date X, warehouse Y had Z units" |

> **Never SUM `inv_quantity_on_hand` across dates** — you will get meaningless results (double-counting stock that sits in a warehouse for multiple days).

## Sample Queries

**Current stock level per item (latest snapshot date):**
```sql
SELECT i.i_product_name, i.i_category, SUM(inv_quantity_on_hand) AS total_stock
FROM staging.inventory inv
JOIN staging.item i ON inv.inv_item_sk = i.i_item_sk
WHERE inv.inv_date_sk = (SELECT MAX(inv_date_sk) FROM staging.inventory)
GROUP BY i.i_product_name, i.i_category
ORDER BY total_stock ASC
LIMIT 20;
```

**Stock trend for a specific item over time:**
```sql
SELECT d.d_date, w.w_warehouse_name, inv.inv_quantity_on_hand
FROM staging.inventory inv
JOIN staging.date_dim d ON inv.inv_date_sk = d.d_date_sk
JOIN staging.warehouse w ON inv.inv_warehouse_sk = w.w_warehouse_sk
WHERE inv.inv_item_sk = 1
ORDER BY d.d_date, w.w_warehouse_name;
```

**Items with low stock (potential out-of-stock risk):**
```sql
SELECT i.i_product_name, w.w_warehouse_name, inv.inv_quantity_on_hand
FROM staging.inventory inv
JOIN staging.item i ON inv.inv_item_sk = i.i_item_sk
JOIN staging.warehouse w ON inv.inv_warehouse_sk = w.w_warehouse_sk
WHERE inv.inv_date_sk = (SELECT MAX(inv_date_sk) FROM staging.inventory)
  AND inv.inv_quantity_on_hand < 10
ORDER BY inv.inv_quantity_on_hand;
```
