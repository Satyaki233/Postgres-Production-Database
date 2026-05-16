# dim_item — Item (Product) Dimension

**Schema:** marts | **Rows:** 102,000 | **Primary Key:** `item_sk`  
**Source:** `staging.item` → `raw.item`

---

## Purpose

Describes every product that can be sold across all three channels — store, web, and catalog.
Contains the full product hierarchy (category → class → brand) and pricing information.

---

## Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `item_sk` | INTEGER | NOT NULL | **Surrogate key.** Referenced as `ss_item_sk`, `ws_item_sk`, `cs_item_sk` in all three fact tables. |
| `item_id` | TEXT | YES | **Natural key.** Source system item identifier. |
| `product_name` | TEXT | YES | Full product name. |
| `brand` | TEXT | YES | Brand name (e.g. `exportiimporto #3`). |
| `brand_id` | INTEGER | YES | Numeric brand identifier. |
| `class` | TEXT | YES | Product class within the category (e.g. `athletic`, `fishing`). More granular than category. |
| `class_id` | INTEGER | YES | Numeric class identifier. |
| `category` | TEXT | YES | Top-level product category (e.g. `Sports`, `Electronics`, `Clothing`, `Books`). |
| `category_id` | INTEGER | YES | Numeric category identifier. |
| `manufacturer` | TEXT | YES | Manufacturer name. |
| `manufacturer_id` | INTEGER | YES | Numeric manufacturer identifier. |
| `size` | TEXT | YES | Size label: `small`, `medium`, `large`, `extra large`, `petite`, `N/A`. |
| `color` | TEXT | YES | Colour description (e.g. `blue`, `red`, `slate`, `saddle`). |
| `units` | TEXT | YES | Unit of measure: `Each`, `Dozen`, `Oz`, `Lb`, `Bundle`, `Pallet` … |
| `container` | TEXT | YES | Packaging type: `Unknown`, `Bag`, `Box`, `Bundle`, `Crate` … |
| `current_price` | NUMERIC | YES | Retail price at the time of this item version. |
| `wholesale_cost` | NUMERIC | YES | Retailer's cost price. Gross margin = `current_price - wholesale_cost`. |
| `valid_from` | DATE | YES | **SCD Type 2:** start date of this item record version. |
| `valid_to` | DATE | YES | **SCD Type 2:** end date of this version. NULL = currently active. |

---

## Product Hierarchy

```
category      (broadest)   Sports
  └── class                  Athletic
        └── brand              Nike #2
              └── item_sk        12345
```

---

## Indexes

`class`, `category`, `brand`

---

## Sample Queries

**Revenue by category:**
```sql
SELECT i.category, SUM(ss_net_paid) AS revenue
FROM marts.fact_store_sales f
JOIN marts.dim_item i ON f.ss_item_sk = i.item_sk
GROUP BY i.category
ORDER BY revenue DESC;
```

**Margin analysis by brand:**
```sql
SELECT
    i.brand,
    SUM(ss_ext_sales_price)    AS revenue,
    SUM(ss_ext_wholesale_cost) AS cost,
    SUM(ss_net_profit)         AS gross_profit,
    ROUND(SUM(ss_net_profit) / NULLIF(SUM(ss_ext_sales_price), 0) * 100, 2) AS margin_pct
FROM marts.fact_store_sales f
JOIN marts.dim_item i ON f.ss_item_sk = i.item_sk
GROUP BY i.brand
ORDER BY gross_profit DESC
LIMIT 20;
```

---

## Notes

- `valid_from` / `valid_to` are **SCD Type 2** columns. If an item's price or attributes changed, a new row was created with a new `item_sk`. The `item_id` (natural key) stays the same across versions. This means an old sale always points to the item's price at the time of the sale.
- `current_price` is the price on the item record — not the actual sale price. The sale price is `ss_sales_price` in the fact table (it may be discounted).
- The same item (`item_id`) can appear in all three channels with the same or different pricing.
