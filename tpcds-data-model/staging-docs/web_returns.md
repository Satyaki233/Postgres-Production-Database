# staging.web_returns — Web Channel Returns

**Rows:** 719,217 | **Source:** `raw.web_returns`

Web order return events. Similar structure to `catalog_returns` with two customer keys
(refunded vs returning) but references web page instead of catalog page or call centre.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `wr_returned_date_sk` | INTEGER | FK → `date_dim`. Date return was processed. |
| `wr_returned_time_sk` | INTEGER | FK → `time_dim`. Time of return. |
| `wr_item_sk` | INTEGER | FK → `item`. Item being returned. |
| `wr_refunded_customer_sk` | INTEGER | FK → `customer`. Customer receiving the refund. |
| `wr_refunded_cdemo_sk` | INTEGER | FK → `customer_demographics`. Demographics of refund recipient. |
| `wr_refunded_hdemo_sk` | INTEGER | FK → `household_demographics`. Household of refund recipient. |
| `wr_refunded_addr_sk` | INTEGER | FK → `customer_address`. Address of refund recipient. |
| `wr_returning_customer_sk` | INTEGER | FK → `customer`. Customer physically returning the item. |
| `wr_returning_cdemo_sk` | INTEGER | FK → `customer_demographics`. Demographics of returner. |
| `wr_returning_hdemo_sk` | INTEGER | FK → `household_demographics`. Household of returner. |
| `wr_returning_addr_sk` | INTEGER | FK → `customer_address`. Address of returner. |
| `wr_web_page_sk` | INTEGER | FK → `web_page`. Page where the original purchase was made. |
| `wr_reason_sk` | INTEGER | FK → `reason`. Return reason code. |
| `wr_order_number` | BIGINT | Original order number. Links to `web_sales.ws_order_number`. |
| `wr_return_quantity` | INTEGER | Units returned. |
| `wr_return_amt` | NUMERIC | Return amount before tax. |
| `wr_return_tax` | NUMERIC | Tax refunded. |
| `wr_return_amt_inc_tax` | NUMERIC | Total refund including tax. |
| `wr_fee` | NUMERIC | Processing or restocking fee. |
| `wr_return_ship_cost` | NUMERIC | Shipping cost for the return. |
| `wr_refunded_cash` | NUMERIC | Refund as cash. |
| `wr_reversed_charge` | NUMERIC | Credit card reversal. |
| `wr_account_credit` | NUMERIC | Account credit issued (web-specific — replaces `store_credit` in store/catalog). |
| `wr_net_loss` | NUMERIC | Net financial loss to the retailer. |

## Notes
- `wr_account_credit` is unique to web returns (store/catalog use `sr_store_credit` / `cr_store_credit`).
- Link to original sale: `web_returns.wr_order_number = web_sales.ws_order_number AND wr_item_sk = ws_item_sk`.
