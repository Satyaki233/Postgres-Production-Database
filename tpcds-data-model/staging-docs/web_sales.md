# staging.web_sales — Web Channel Sales

**Rows:** 7,197,566 | **Source:** `raw.web_sales`

Cleaned web order line items. 34 columns — same count as catalog_sales but
different channel-specific keys (web page / web site instead of call centre / catalog page).

Compared to `marts.fact_web_sales`, staging has **9 extra columns**.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `ws_sold_date_sk` | INTEGER | FK → `date_dim`. Date order was placed. |
| `ws_sold_time_sk` | INTEGER | FK → `time_dim`. Time order placed. |
| `ws_ship_date_sk` | INTEGER | FK → `date_dim`. Date order was shipped. **Not in marts.** |
| `ws_item_sk` | INTEGER | FK → `item`. |
| `ws_bill_customer_sk` | INTEGER | FK → `customer`. Billing customer (card holder). |
| `ws_bill_cdemo_sk` | INTEGER | FK → `customer_demographics`. Billing demographics. **Not in marts.** |
| `ws_bill_hdemo_sk` | INTEGER | FK → `household_demographics`. Billing household. **Not in marts.** |
| `ws_bill_addr_sk` | INTEGER | FK → `customer_address`. Billing address. **Not in marts.** |
| `ws_ship_customer_sk` | INTEGER | FK → `customer`. Shipping recipient. |
| `ws_ship_cdemo_sk` | INTEGER | FK → `customer_demographics`. Shipping demographics. **Not in marts.** |
| `ws_ship_hdemo_sk` | INTEGER | FK → `household_demographics`. Shipping household. **Not in marts.** |
| `ws_ship_addr_sk` | INTEGER | FK → `customer_address`. Shipping address. **Not in marts.** |
| `ws_web_page_sk` | INTEGER | FK → `web_page`. Page where item was purchased. |
| `ws_web_site_sk` | INTEGER | FK → `web_site`. Site where order was placed. |
| `ws_ship_mode_sk` | INTEGER | FK → `ship_mode`. Shipping method. **Not in marts.** |
| `ws_warehouse_sk` | INTEGER | FK → `warehouse`. Fulfilment warehouse. **Not in marts.** |
| `ws_promo_sk` | INTEGER | FK → `promotion`. NULL = no promo. |
| `ws_order_number` | BIGINT | Order number. Groups all line items in the same cart. |
| `ws_quantity` | INTEGER | Units ordered. |
| `ws_wholesale_cost` | NUMERIC | Cost per unit. |
| `ws_list_price` | NUMERIC | List price per unit. |
| `ws_sales_price` | NUMERIC | Actual price per unit. |
| `ws_ext_discount_amt` | NUMERIC | Total discount. |
| `ws_ext_sales_price` | NUMERIC | `sales_price × quantity`. |
| `ws_ext_wholesale_cost` | NUMERIC | `wholesale_cost × quantity`. |
| `ws_ext_list_price` | NUMERIC | `list_price × quantity`. |
| `ws_ext_tax` | NUMERIC | Tax charged. |
| `ws_coupon_amt` | NUMERIC | Coupon applied. |
| `ws_ext_ship_cost` | NUMERIC | Shipping cost for this line. |
| `ws_net_paid` | NUMERIC | Net paid before shipping. |
| `ws_net_paid_inc_tax` | NUMERIC | Net paid including tax. |
| `ws_net_paid_inc_ship` | NUMERIC | Net paid including shipping. |
| `ws_net_paid_inc_ship_tax` | NUMERIC | Total customer spend. |
| `ws_net_profit` | NUMERIC | Retailer profit. |

## Key Staging-Only Columns

| Column | Use case |
|--------|----------|
| `ws_ship_date_sk` | Fulfilment lag: `ws_ship_date_sk − ws_sold_date_sk` in days |
| `ws_ship_mode_sk` | Shipping method analysis |
| `ws_warehouse_sk` | Which warehouse fulfils web orders |
| `ws_bill_addr_sk` | Billing address — compare to `ws_ship_addr_sk` for gift detection |
