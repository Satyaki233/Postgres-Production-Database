# staging.store_sales — In-Store Sales

**Rows:** 28,800,991 | **Source:** `raw.store_sales`

Cleaned version of in-store sales line items. Identical grain and column set to raw —
one row per item sold per receipt — with strings trimmed.

Compared to `marts.fact_store_sales`, staging has **3 extra columns** not in marts:
`ss_cdemo_sk`, `ss_hdemo_sk`, `ss_addr_sk`.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `ss_sold_date_sk` | INTEGER | FK → `date_dim`. Sale date. |
| `ss_sold_time_sk` | INTEGER | FK → `time_dim`. Sale time. |
| `ss_item_sk` | INTEGER | FK → `item`. |
| `ss_customer_sk` | INTEGER | FK → `customer`. NULL = anonymous. |
| `ss_cdemo_sk` | INTEGER | FK → `customer_demographics`. Demographics at time of sale. **Not in marts.** |
| `ss_hdemo_sk` | INTEGER | FK → `household_demographics`. Household at time of sale. **Not in marts.** |
| `ss_addr_sk` | INTEGER | FK → `customer_address`. Address at time of sale. **Not in marts.** |
| `ss_store_sk` | INTEGER | FK → `store`. |
| `ss_promo_sk` | INTEGER | FK → `promotion`. NULL = no promo. |
| `ss_ticket_number` | BIGINT | Receipt number. Groups line items in the same basket. |
| `ss_quantity` | INTEGER | Units sold. |
| `ss_wholesale_cost` | NUMERIC | Cost per unit. |
| `ss_list_price` | NUMERIC | List price per unit. |
| `ss_sales_price` | NUMERIC | Actual price per unit after discount. |
| `ss_ext_discount_amt` | NUMERIC | Total discount: `(list_price − sales_price) × quantity`. |
| `ss_ext_sales_price` | NUMERIC | `sales_price × quantity`. |
| `ss_ext_wholesale_cost` | NUMERIC | `wholesale_cost × quantity`. |
| `ss_ext_list_price` | NUMERIC | `list_price × quantity`. |
| `ss_ext_tax` | NUMERIC | Tax collected. |
| `ss_coupon_amt` | NUMERIC | Coupon value applied. |
| `ss_net_paid` | NUMERIC | `ext_sales_price − coupon_amt`. |
| `ss_net_paid_inc_tax` | NUMERIC | `net_paid + ext_tax`. |
| `ss_net_profit` | NUMERIC | `net_paid − ext_wholesale_cost`. |

## When to Use Staging vs Marts

| Need | Use |
|------|-----|
| Revenue, profit, quantity reports | `marts.fact_store_sales` (indexed, faster) |
| Demographics at time of sale (`ss_cdemo_sk`) | `staging.store_sales` |
| Household data at time of sale (`ss_hdemo_sk`) | `staging.store_sales` |
| Address at time of sale (`ss_addr_sk`) | `staging.store_sales` |
