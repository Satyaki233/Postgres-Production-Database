# staging.catalog_returns — Catalog Channel Returns

**Rows:** 1,439,749 | **Source:** `raw.catalog_returns`

Catalog order return events. A customer returning a catalog item can receive a refund
as cash, credit card reversal, or store credit — all three are tracked separately.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `cr_returned_date_sk` | INTEGER | FK → `date_dim`. Date the return was processed. |
| `cr_returned_time_sk` | INTEGER | FK → `time_dim`. Time of return. |
| `cr_item_sk` | INTEGER | FK → `item`. Item being returned. |
| `cr_refunded_customer_sk` | INTEGER | FK → `customer`. Customer receiving the refund (original buyer). |
| `cr_refunded_cdemo_sk` | INTEGER | FK → `customer_demographics`. Demographics of refund recipient. |
| `cr_refunded_hdemo_sk` | INTEGER | FK → `household_demographics`. Household of refund recipient. |
| `cr_refunded_addr_sk` | INTEGER | FK → `customer_address`. Address of refund recipient. |
| `cr_returning_customer_sk` | INTEGER | FK → `customer`. Customer physically returning the item (may differ from buyer). |
| `cr_returning_cdemo_sk` | INTEGER | FK → `customer_demographics`. Demographics of returner. |
| `cr_returning_hdemo_sk` | INTEGER | FK → `household_demographics`. Household of returner. |
| `cr_returning_addr_sk` | INTEGER | FK → `customer_address`. Address of returner. |
| `cr_call_center_sk` | INTEGER | FK → `call_center`. Call centre that processed the return. |
| `cr_catalog_page_sk` | INTEGER | FK → `catalog_page`. Page the item was originally ordered from. |
| `cr_ship_mode_sk` | INTEGER | FK → `ship_mode`. Shipping method for the return. |
| `cr_warehouse_sk` | INTEGER | FK → `warehouse`. Warehouse receiving the returned item. |
| `cr_reason_sk` | INTEGER | FK → `reason`. Return reason code. |
| `cr_order_number` | BIGINT | Original order number. Links return to original sale in `catalog_sales`. |
| `cr_return_quantity` | INTEGER | Units returned. |
| `cr_return_amount` | NUMERIC | Return amount before tax. |
| `cr_return_tax` | NUMERIC | Tax refunded. |
| `cr_return_amt_inc_tax` | NUMERIC | Total refund including tax. |
| `cr_fee` | NUMERIC | Restocking or processing fee. |
| `cr_return_ship_cost` | NUMERIC | Cost of shipping the return. |
| `cr_refunded_cash` | NUMERIC | Refund issued as cash. |
| `cr_reversed_charge` | NUMERIC | Credit card reversal amount. |
| `cr_store_credit` | NUMERIC | Store credit issued. |
| `cr_net_loss` | NUMERIC | Net financial loss to the retailer. |

## Notes
- Two customer keys: `cr_refunded_customer_sk` (who gets the money) vs `cr_returning_customer_sk` (who brings the item back). They differ when a gift recipient returns an item.
- Link to original sale: `catalog_returns.cr_order_number = catalog_sales.cs_order_number AND cr_item_sk = cs_item_sk`.
