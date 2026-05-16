# fact_catalog_sales — Catalog Channel Sales Fact Table

**Schema:** marts | **Rows:** 14,401,261 | **Size:** ~2.9 GB  
**Grain:** One row = one line item on one catalog (phone/mail) order  
**Partition key:** `cs_sold_date_sk` (RANGE)  
**Source:** `staging.catalog_sales` → `raw.catalog_sales`

---

## Purpose

Records every item sold through the catalog channel — phone orders and
mail-in orders from printed catalogues. Structurally identical to `fact_web_sales`
but references call centres and catalog pages instead of web pages and web sites.

---

## Foreign Keys

| Column | References | Nullable | Notes |
|--------|-----------|----------|-------|
| `cs_sold_date_sk` | `dim_date.date_sk` | YES | NULL = order date unknown |
| `cs_item_sk` | `dim_item.item_sk` | NOT NULL | Always known |
| `cs_bill_customer_sk` | `dim_customer.customer_sk` | YES | Who paid. NULL = unknown |
| `cs_ship_customer_sk` | `dim_customer.customer_sk` | YES | Who received the order |
| `cs_promo_sk` | `dim_promotion.promo_sk` | YES | NULL = no promotion |

> `cs_call_center_sk` and `cs_catalog_page_sk` link to `raw.call_center` and `raw.catalog_page` — no marts dimension was created for these.

---

## All Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `cs_sold_date_sk` | INTEGER | YES | Date order placed → join to `dim_date`. |
| `cs_sold_time_sk` | INTEGER | YES | Time order placed → links to `raw.time_dim`. |
| `cs_item_sk` | INTEGER | NOT NULL | Item ordered → join to `dim_item`. |
| `cs_bill_customer_sk` | INTEGER | YES | Billing customer → join to `dim_customer`. |
| `cs_ship_customer_sk` | INTEGER | YES | Shipping recipient → join to `dim_customer`. |
| `cs_call_center_sk` | INTEGER | YES | **Catalog only.** Call centre that handled this order (links to `raw.call_center`). |
| `cs_catalog_page_sk` | INTEGER | YES | **Catalog only.** Page in the printed catalogue that listed this item (links to `raw.catalog_page`). |
| `cs_promo_sk` | INTEGER | YES | Promotion applied → join to `dim_promotion`. NULL = no promo. |
| `cs_order_number` | BIGINT | NOT NULL | Order number. Groups all line items in the same catalog order. |
| `cs_quantity` | INTEGER | YES | Units ordered. |
| `cs_wholesale_cost` | NUMERIC(7,2) | YES | Retailer's cost price per unit. |
| `cs_list_price` | NUMERIC(7,2) | YES | Original price before discount. |
| `cs_sales_price` | NUMERIC(7,2) | YES | Actual unit price charged after discount. |
| `cs_ext_discount_amt` | NUMERIC(7,2) | YES | Total discount on this line. |
| `cs_ext_sales_price` | NUMERIC(7,2) | YES | `sales_price × quantity`. |
| `cs_ext_wholesale_cost` | NUMERIC(7,2) | YES | `wholesale_cost × quantity`. |
| `cs_ext_list_price` | NUMERIC(7,2) | YES | `list_price × quantity`. |
| `cs_ext_tax` | NUMERIC(7,2) | YES | Tax charged on this line. |
| `cs_coupon_amt` | NUMERIC(7,2) | YES | Coupon value applied. |
| `cs_ext_ship_cost` | NUMERIC(7,2) | YES | **Web/catalog only.** Shipping cost for this line item. |
| `cs_net_paid` | NUMERIC(7,2) | YES | Net paid before shipping: `ext_sales_price − coupon_amt`. |
| `cs_net_paid_inc_tax` | NUMERIC(7,2) | YES | Net paid including tax. |
| `cs_net_paid_inc_ship` | NUMERIC(7,2) | YES | Net paid including shipping. |
| `cs_net_paid_inc_ship_tax` | NUMERIC(7,2) | YES | Total customer spend: net paid + shipping + tax. |
| `cs_net_profit` | NUMERIC(7,2) | YES | Retailer profit: `net_paid − ext_wholesale_cost − ext_ship_cost`. |

---

## Differences from fact_web_sales

| | fact_web_sales | fact_catalog_sales |
|---|---|---|
| Origin | Web browser | Phone / mail-in |
| Channel-specific key | `ws_web_page_sk`, `ws_web_site_sk` | `cs_call_center_sk`, `cs_catalog_page_sk` |
| Transaction ID | `ws_order_number` | `cs_order_number` |
| Measures | Identical | Identical |

---

## Indexes

`cs_sold_date_sk`, `cs_bill_customer_sk`, `cs_item_sk`, `cs_promo_sk`

---

## Sample Queries

**Catalog revenue by item category:**
```sql
SELECT i.category, SUM(cs_net_paid) AS revenue
FROM marts.fact_catalog_sales f
JOIN marts.dim_item i ON f.cs_item_sk = i.item_sk
GROUP BY i.category
ORDER BY revenue DESC;
```

**Which promotions drove catalog orders:**
```sql
SELECT
    p.purpose,
    p.channel_catalog,
    COUNT(*)         AS line_items,
    SUM(cs_net_paid) AS revenue
FROM marts.fact_catalog_sales f
JOIN marts.dim_promotion p ON f.cs_promo_sk = p.promo_sk
GROUP BY p.purpose, p.channel_catalog
ORDER BY revenue DESC;
```

**Three-channel revenue comparison:**
```sql
SELECT channel, SUM(revenue) AS total_revenue
FROM (
    SELECT 'store'   AS channel, ss_net_paid AS revenue FROM marts.fact_store_sales
    UNION ALL
    SELECT 'web',                ws_net_paid            FROM marts.fact_web_sales
    UNION ALL
    SELECT 'catalog',            cs_net_paid            FROM marts.fact_catalog_sales
) t
GROUP BY channel
ORDER BY total_revenue DESC;
```

---

## Notes

- Use `LEFT JOIN` for `cs_bill_customer_sk`, `cs_ship_customer_sk`, and `cs_promo_sk`.
- `cs_net_paid_inc_ship_tax` is the true total spend column — includes shipping, which is significant for catalog orders.
- `cs_catalog_page_sk` is useful for attribution: which page in the printed catalogue generated the most orders.
- `cs_call_center_sk` lets you analyse agent / call-centre performance (links to `raw.call_center` which has agent and market data).
