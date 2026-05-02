# staging.catalog_sales — Catalog Channel Sales

**Rows:** 14,401,261 | **Source:** `raw.catalog_sales`

Cleaned catalog order line items. Has 34 columns — the richest of the three sales
tables because catalog orders track separate bill/ship demographics, the warehouse
fulfilled from, and the ship date in addition to the order date.

Compared to `marts.fact_catalog_sales`, staging has **9 extra columns**.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `cs_sold_date_sk` | INTEGER | FK → `date_dim`. Date order was placed. |
| `cs_sold_time_sk` | INTEGER | FK → `time_dim`. Time order was placed. |
| `cs_ship_date_sk` | INTEGER | FK → `date_dim`. Date order was shipped. **Not in marts.** |
| `cs_bill_customer_sk` | INTEGER | FK → `customer`. Billing customer. |
| `cs_bill_cdemo_sk` | INTEGER | FK → `customer_demographics`. Billing demographics. **Not in marts.** |
| `cs_bill_hdemo_sk` | INTEGER | FK → `household_demographics`. Billing household. **Not in marts.** |
| `cs_bill_addr_sk` | INTEGER | FK → `customer_address`. Billing address. **Not in marts.** |
| `cs_ship_customer_sk` | INTEGER | FK → `customer`. Shipping recipient. |
| `cs_ship_cdemo_sk` | INTEGER | FK → `customer_demographics`. Shipping demographics. **Not in marts.** |
| `cs_ship_hdemo_sk` | INTEGER | FK → `household_demographics`. Shipping household. **Not in marts.** |
| `cs_ship_addr_sk` | INTEGER | FK → `customer_address`. Shipping address. **Not in marts.** |
| `cs_call_center_sk` | INTEGER | FK → `call_center`. Call centre that took the order. |
| `cs_catalog_page_sk` | INTEGER | FK → `catalog_page`. Page the item was listed on. |
| `cs_ship_mode_sk` | INTEGER | FK → `ship_mode`. Shipping method. **Not in marts.** |
| `cs_warehouse_sk` | INTEGER | FK → `warehouse`. Warehouse fulfilled from. **Not in marts.** |
| `cs_item_sk` | INTEGER | FK → `item`. |
| `cs_promo_sk` | INTEGER | FK → `promotion`. NULL = no promo. |
| `cs_order_number` | BIGINT | Order number. Groups all items on the same order. |
| `cs_quantity` | INTEGER | Units ordered. |
| `cs_wholesale_cost` | NUMERIC | Cost per unit. |
| `cs_list_price` | NUMERIC | List price per unit. |
| `cs_sales_price` | NUMERIC | Actual price per unit. |
| `cs_ext_discount_amt` | NUMERIC | Total discount. |
| `cs_ext_sales_price` | NUMERIC | `sales_price × quantity`. |
| `cs_ext_wholesale_cost` | NUMERIC | `wholesale_cost × quantity`. |
| `cs_ext_list_price` | NUMERIC | `list_price × quantity`. |
| `cs_ext_tax` | NUMERIC | Tax charged. |
| `cs_coupon_amt` | NUMERIC | Coupon applied. |
| `cs_ext_ship_cost` | NUMERIC | Shipping cost. |
| `cs_net_paid` | NUMERIC | Net paid before shipping. |
| `cs_net_paid_inc_tax` | NUMERIC | Net paid including tax. |
| `cs_net_paid_inc_ship` | NUMERIC | Net paid including shipping. |
| `cs_net_paid_inc_ship_tax` | NUMERIC | Total customer spend. |
| `cs_net_profit` | NUMERIC | Retailer profit. |

## Key Staging-Only Columns

| Column | Use case |
|--------|----------|
| `cs_ship_date_sk` | Calculate fulfilment lag: `cs_ship_date_sk − cs_sold_date_sk` |
| `cs_ship_mode_sk` | Analyse revenue vs shipping method |
| `cs_warehouse_sk` | Analyse which warehouse fulfils the most orders |
| `cs_bill_cdemo_sk` / `cs_ship_cdemo_sk` | Demographics of the person who paid vs who received |
