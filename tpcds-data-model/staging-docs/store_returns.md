# staging.store_returns — In-Store Returns

**Rows:** 2,875,357 | **Source:** `raw.store_returns`

In-store return events. Each row records one item being returned to a physical store.
Approximately 10% of store_sales rows become returns (expected TPC-DS ratio).

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `sr_returned_date_sk` | INTEGER | FK → `date_dim`. Date the item was returned. |
| `sr_return_time_sk` | INTEGER | FK → `time_dim`. Time the return was processed. |
| `sr_item_sk` | INTEGER | FK → `item`. Item being returned. |
| `sr_customer_sk` | INTEGER | FK → `customer`. Customer who returned the item. NULL = anonymous. |
| `sr_cdemo_sk` | INTEGER | FK → `customer_demographics`. Demographics at time of return. |
| `sr_hdemo_sk` | INTEGER | FK → `household_demographics`. Household at time of return. |
| `sr_addr_sk` | INTEGER | FK → `customer_address`. Address at time of return. |
| `sr_store_sk` | INTEGER | FK → `store`. Store where item was returned. |
| `sr_reason_sk` | INTEGER | FK → `reason`. Why the item was returned. |
| `sr_ticket_number` | BIGINT | Original receipt number. Links the return to the original sale in `store_sales`. |
| `sr_return_quantity` | INTEGER | Units returned. |
| `sr_return_amt` | NUMERIC | Return amount before tax. |
| `sr_return_tax` | NUMERIC | Tax refunded. |
| `sr_return_amt_inc_tax` | NUMERIC | Total refund including tax. |
| `sr_fee` | NUMERIC | Restocking or processing fee charged to the customer. |
| `sr_return_ship_cost` | NUMERIC | Shipping cost for the return (if applicable). |
| `sr_refunded_cash` | NUMERIC | Amount refunded as cash. |
| `sr_reversed_charge` | NUMERIC | Credit card reversal amount. |
| `sr_store_credit` | NUMERIC | Store credit issued instead of cash. |
| `sr_net_loss` | NUMERIC | Net financial loss to the retailer on this return. |

## Key Relationships
- Join to original sale: `store_returns.sr_ticket_number = store_sales.ss_ticket_number AND sr_item_sk = ss_item_sk`
- `sr_net_loss = sr_return_amt − sr_fee` — the true cost to the retailer.

## Sample Query
```sql
-- Return rate by item category
SELECT i.i_category,
       COUNT(sr.sr_item_sk)    AS returns,
       COUNT(ss.ss_item_sk)    AS sales,
       ROUND(COUNT(sr.sr_item_sk)::numeric / COUNT(ss.ss_item_sk) * 100, 2) AS return_rate_pct
FROM staging.store_sales ss
JOIN staging.item i ON ss.ss_item_sk = i.i_item_sk
LEFT JOIN staging.store_returns sr
       ON sr.sr_ticket_number = ss.ss_ticket_number
      AND sr.sr_item_sk = ss.ss_item_sk
GROUP BY i.i_category
ORDER BY return_rate_pct DESC;
```
