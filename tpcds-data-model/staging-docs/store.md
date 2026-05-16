# staging.store — Physical Store Locations

**Rows:** 102 | **Source:** `raw.store`

Full store master with all 29 TPC-DS columns. The marts layer promotes
a simplified 17-column version as `marts.dim_store`. Use staging when you
need corporate hierarchy columns (`s_division_*`, `s_company_*`) or full address.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `s_store_sk` | INTEGER | Surrogate key. Referenced as `ss_store_sk` in `store_sales` and `store_returns`. |
| `s_store_id` | CHAR(16) | Natural key. |
| `s_rec_start_date` | DATE | SCD Type 2 effective start date. |
| `s_rec_end_date` | DATE | SCD Type 2 end date. NULL = active. |
| `s_closed_date_sk` | INTEGER | FK → `date_dim`. Date the store closed. NULL = still open. |
| `s_store_name` | VARCHAR | Store name. |
| `s_number_employees` | INTEGER | Employee count. |
| `s_floor_space` | INTEGER | Floor area in square feet. |
| `s_hours` | CHAR(20) | Operating hours (e.g. `8AM-4PM`). |
| `s_manager` | VARCHAR | Store manager name. |
| `s_market_id` | INTEGER | Regional market group ID. |
| `s_geography_class` | VARCHAR | Geographic classification. **Not in marts.** |
| `s_market_desc` | VARCHAR | Market description. |
| `s_market_manager` | VARCHAR | Regional market manager name. **Not in marts.** |
| `s_division_id` | INTEGER | Corporate division ID. **Not in marts.** |
| `s_division_name` | VARCHAR | Corporate division name. **Not in marts.** |
| `s_company_id` | INTEGER | Company ID. **Not in marts.** |
| `s_company_name` | VARCHAR | Company name. **Not in marts.** |
| `s_street_number` | VARCHAR | Street number. |
| `s_street_name` | VARCHAR | Street name. |
| `s_street_type` | CHAR(15) | Street type. |
| `s_suite_number` | CHAR(10) | Suite number. |
| `s_city` | VARCHAR | City. |
| `s_county` | VARCHAR | County. |
| `s_state` | CHAR(2) | State code. |
| `s_zip` | CHAR(10) | ZIP code. |
| `s_country` | VARCHAR | Country. |
| `s_gmt_offset` | NUMERIC | Timezone offset. |
| `s_tax_precentage` | NUMERIC | Local sales tax rate. (Note: TPC-DS typo — "precentage" is in the spec.) |

## Notes
- `s_closed_date_sk` is useful for filtering active stores: `WHERE s_closed_date_sk IS NULL`.
- Use staging for corporate hierarchy analysis (`s_division_name`, `s_company_name`).
- `s_tax_precentage` is the TPC-DS spec column name — the typo is intentional (matches raw).
