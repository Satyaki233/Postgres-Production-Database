# fact_store_sales — In-Store Sales Fact Table

**Schema:** marts | **Rows:** 28,800,991 | **Size:** ~4.8 GB  
**Grain:** One row = one line item on one in-store receipt  
**Partition key:** `ss_sold_date_sk` (RANGE)  
**Source:** `staging.store_sales` → `raw.store_sales`

---

## Purpose

Records every individual item sold in a physical retail store.
The largest fact table in the warehouse (~2× catalog, ~4× web).

Each row answers: *on what date, at which store, did which customer buy which item,
under which promotion, and for how much?*

---

## Foreign Keys

| Column | References | Nullable | Notes |
|--------|-----------|----------|-------|
| `ss_sold_date_sk` | `dim_date.date_sk` | YES | NULL = sale date unknown |
| `ss_item_sk` | `dim_item.item_sk` | NOT NULL | Always known |
| `ss_customer_sk` | `dim_customer.customer_sk` | YES | NULL = anonymous/guest sale |
| `ss_store_sk` | `dim_store.store_sk` | YES | NULL = store unknown |
| `ss_promo_sk` | `dim_promotion.promo_sk` | YES | NULL = no promotion applied |

---

## All Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `ss_sold_date_sk` | INTEGER | YES | Date of the sale → join to `dim_date`. |
| `ss_sold_time_sk` | INTEGER | YES | Time of day → links to `raw.time_dim` (no marts dim). |
| `ss_item_sk` | INTEGER | NOT NULL | Item sold → join to `dim_item`. |
| `ss_customer_sk` | INTEGER | YES | Customer → join to `dim_customer`. NULL = anonymous. |
| `ss_store_sk` | INTEGER | YES | Store → join to `dim_store`. |
| `ss_promo_sk` | INTEGER | YES | Promotion → join to `dim_promotion`. NULL = no promo. |
| `ss_ticket_number` | BIGINT | NOT NULL | Receipt number. Groups all line items from the same basket. |
| `ss_quantity` | INTEGER | YES | Units sold on this line item. |
| `ss_wholesale_cost` | NUMERIC(7,2) | YES | Retailer's cost price per unit. |
| `ss_list_price` | NUMERIC(7,2) | YES | Original price tag per unit before any discount. |
| `ss_sales_price` | NUMERIC(7,2) | YES | Actual unit price the customer agreed to pay (after discount). |
| `ss_ext_discount_amt` | NUMERIC(7,2) | YES | Total discount: `(list_price − sales_price) × quantity`. |
| `ss_ext_sales_price` | NUMERIC(7,2) | YES | Extended sales price: `sales_price × quantity`. Line total before coupon. |
| `ss_ext_wholesale_cost` | NUMERIC(7,2) | YES | Extended wholesale cost: `wholesale_cost × quantity`. |
| `ss_ext_list_price` | NUMERIC(7,2) | YES | Extended list price: `list_price × quantity`. |
| `ss_ext_tax` | NUMERIC(7,2) | YES | Sales tax collected on this line item. |
| `ss_coupon_amt` | NUMERIC(7,2) | YES | Coupon / voucher value applied at checkout. |
| `ss_net_paid` | NUMERIC(7,2) | YES | Money that actually changed hands: `ext_sales_price − coupon_amt`. |
| `ss_net_paid_inc_tax` | NUMERIC(7,2) | YES | Total out-of-pocket for customer: `net_paid + ext_tax`. |
| `ss_net_profit` | NUMERIC(7,2) | YES | Retailer profit: `net_paid − ext_wholesale_cost`. |

---

## How the Money Columns Relate

```
ss_list_price           Price on the tag (per unit)
  − discount            Promotional markdown
= ss_sales_price        What customer pays per unit
  × ss_quantity
= ss_ext_sales_price    Line total before coupon
  − ss_coupon_amt       Voucher at checkout
= ss_net_paid           Cash received
  + ss_ext_tax
= ss_net_paid_inc_tax   Customer's total bill

ss_net_profit = ss_net_paid − ss_ext_wholesale_cost
```

---

## Indexes

`ss_sold_date_sk`, `ss_customer_sk`, `ss_item_sk`, `ss_store_sk`, `ss_promo_sk`

---

## Sample Queries

**Monthly revenue:**
```sql
SELECT d.year, d.month, SUM(ss_net_paid) AS revenue
FROM marts.fact_store_sales f
JOIN marts.dim_date d ON f.ss_sold_date_sk = d.date_sk
GROUP BY d.year, d.month
ORDER BY d.year, d.month;
```

**Top 10 most profitable products:**
```sql
SELECT i.product_name, i.category, SUM(ss_net_profit) AS profit
FROM marts.fact_store_sales f
JOIN marts.dim_item i ON f.ss_item_sk = i.item_sk
GROUP BY i.product_name, i.category
ORDER BY profit DESC
LIMIT 10;
```

**Average basket size (items per receipt):**
```sql
SELECT ROUND(AVG(items_per_ticket), 2) AS avg_basket_size
FROM (
    SELECT ss_ticket_number, COUNT(*) AS items_per_ticket
    FROM marts.fact_store_sales
    GROUP BY ss_ticket_number
) t;
```

---

## Notes

- Use `LEFT JOIN` for `dim_customer` and `dim_promotion` — NULLs in those FK columns are valid.
- `ss_ticket_number` groups line items into a single transaction (basket). Aggregate by it to analyse basket size or total receipt value.
- `ss_net_profit` can be negative — this happens when coupons or discounts exceed the wholesale cost.
