# fact_web_sales — Web Channel Sales Fact Table

**Schema:** marts | **Rows:** 7,197,566 | **Size:** ~1.4 GB  
**Grain:** One row = one line item on one online order  
**Partition key:** `ws_sold_date_sk` (RANGE)  
**Source:** `staging.web_sales` → `raw.web_sales`

---

## Purpose

Records every individual item sold through the web (online) channel.
Has two customer keys — billing and shipping — because online orders can be
delivered to a different address than the card holder (gift orders).
Also includes a shipping cost column not present in store sales.

---

## Foreign Keys

| Column                | References                 | Nullable | Notes                                  |
| --------------------- | -------------------------- | -------- | -------------------------------------- |
| `ws_sold_date_sk`     | `dim_date.date_sk`         | YES      | NULL = order date unknown              |
| `ws_item_sk`          | `dim_item.item_sk`         | NOT NULL | Always known                           |
| `ws_bill_customer_sk` | `dim_customer.customer_sk` | YES      | Who paid. NULL = guest checkout        |
| `ws_ship_customer_sk` | `dim_customer.customer_sk` | YES      | Who received the order. NULL = unknown |
| `ws_promo_sk`         | `dim_promotion.promo_sk`   | YES      | NULL = no promotion                    |

> `ws_web_page_sk` and `ws_web_site_sk` link to `raw.web_page` and `raw.web_site` — no marts dimension was created for these.

---

## All Columns

| Column                     | Type         | Nullable | Description                                                                     |
| -------------------------- | ------------ | -------- | ------------------------------------------------------------------------------- |
| `ws_sold_date_sk`          | INTEGER      | YES      | Date order placed → join to `dim_date`.                                         |
| `ws_sold_time_sk`          | INTEGER      | YES      | Time order placed → links to `raw.time_dim`.                                    |
| `ws_item_sk`               | INTEGER      | NOT NULL | Item ordered → join to `dim_item`.                                              |
| `ws_bill_customer_sk`      | INTEGER      | YES      | Billing customer (card holder) → join to `dim_customer`.                        |
| `ws_ship_customer_sk`      | INTEGER      | YES      | Shipping recipient → join to `dim_customer`. Can differ from billing for gifts. |
| `ws_web_page_sk`           | INTEGER      | YES      | Web page where item was purchased.                                              |
| `ws_web_site_sk`           | INTEGER      | YES      | Web site / domain where order was placed.                                       |
| `ws_promo_sk`              | INTEGER      | YES      | Promotion applied → join to `dim_promotion`. NULL = no promo.                   |
| `ws_order_number`          | BIGINT       | NOT NULL | Order number. Groups all line items in the same web order.                      |
| `ws_quantity`              | INTEGER      | YES      | Units ordered.                                                                  |
| `ws_wholesale_cost`        | NUMERIC(7,2) | YES      | Retailer's cost price per unit.                                                 |
| `ws_list_price`            | NUMERIC(7,2) | YES      | Original price before discount.                                                 |
| `ws_sales_price`           | NUMERIC(7,2) | YES      | Actual unit price charged after discount.                                       |
| `ws_ext_discount_amt`      | NUMERIC(7,2) | YES      | Total discount on this line.                                                    |
| `ws_ext_sales_price`       | NUMERIC(7,2) | YES      | `sales_price × quantity`.                                                       |
| `ws_ext_wholesale_cost`    | NUMERIC(7,2) | YES      | `wholesale_cost × quantity`.                                                    |
| `ws_ext_list_price`        | NUMERIC(7,2) | YES      | `list_price × quantity`.                                                        |
| `ws_ext_tax`               | NUMERIC(7,2) | YES      | Tax charged on this line.                                                       |
| `ws_coupon_amt`            | NUMERIC(7,2) | YES      | Coupon value applied.                                                           |
| `ws_ext_ship_cost`         | NUMERIC(7,2) | YES      | **Web/catalog only.** Shipping cost for this line item.                         |
| `ws_net_paid`              | NUMERIC(7,2) | YES      | Net paid before shipping: `ext_sales_price − coupon_amt`.                       |
| `ws_net_paid_inc_tax`      | NUMERIC(7,2) | YES      | Net paid including tax.                                                         |
| `ws_net_paid_inc_ship`     | NUMERIC(7,2) | YES      | Net paid including shipping.                                                    |
| `ws_net_paid_inc_ship_tax` | NUMERIC(7,2) | YES      | Total customer spend: net paid + shipping + tax.                                |
| `ws_net_profit`            | NUMERIC(7,2) | YES      | Retailer profit: `net_paid − ext_wholesale_cost − ext_ship_cost`.               |

---

## Differences from fact_store_sales

|                 | fact_store_sales      | fact_web_sales                 |
| --------------- | --------------------- | ------------------------------ |
| Customer keys   | 1 (`ss_customer_sk`)  | 2 (`bill` + `ship`)            |
| Shipping cost   | —                     | `ws_ext_ship_cost`             |
| Full total paid | `ss_net_paid_inc_tax` | `ws_net_paid_inc_ship_tax`     |
| Transaction ID  | `ss_ticket_number`    | `ws_order_number`              |
| Location dim    | `dim_store`           | web_page / web_site (raw only) |

---

## Indexes

`ws_sold_date_sk`, `ws_bill_customer_sk`, `ws_item_sk`, `ws_promo_sk`

---

## Sample Queries

**Total web revenue including shipping:**

```sql
SELECT d.year, d.month, SUM(ws_net_paid_inc_ship_tax) AS total_revenue
FROM marts.fact_web_sales f
JOIN marts.dim_date d ON f.ws_sold_date_sk = d.date_sk
GROUP BY d.year, d.month
ORDER BY d.year, d.month;
```

**Gift orders (bill ≠ ship customer):**

```sql
SELECT COUNT(*) AS gift_line_items
FROM marts.fact_web_sales
WHERE ws_bill_customer_sk IS DISTINCT FROM ws_ship_customer_sk
  AND ws_bill_customer_sk IS NOT NULL
  AND ws_ship_customer_sk IS NOT NULL;
```

**Cross-channel comparison:**

```sql
SELECT 'web' AS channel, SUM(ws_net_paid) AS revenue FROM marts.fact_web_sales
UNION ALL
SELECT 'store',          SUM(ss_net_paid) FROM marts.fact_store_sales
UNION ALL
SELECT 'catalog',        SUM(cs_net_paid) FROM marts.fact_catalog_sales;
```

---

## Notes

- Use `LEFT JOIN` for both `ws_bill_customer_sk` and `ws_ship_customer_sk` — both can be NULL (guest checkout or unknown recipient).
- Use `ws_net_paid_inc_ship_tax` as the true "total spend" column for web sales — it includes shipping, which is a significant cost unique to this channel.
- `ws_order_number` groups line items into one order (like a cart). The same order can have multiple items.
