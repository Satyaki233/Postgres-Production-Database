# staging.call_center — Call Centre Locations

**Rows:** 24 | **Source:** `raw.call_center`

Call centre master records. Referenced only by `catalog_sales` and `catalog_returns`
via `*_call_center_sk`. No marts dimension — query staging for call centre analysis.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `cc_call_center_sk` | INTEGER | Surrogate key. Referenced as `cs_call_center_sk`, `cr_call_center_sk`. |
| `cc_call_center_id` | CHAR(16) | Natural key. |
| `cc_rec_start_date` | DATE | SCD Type 2 effective start date. |
| `cc_rec_end_date` | DATE | SCD Type 2 end date. NULL = active. |
| `cc_closed_date_sk` | INTEGER | FK → `date_dim`. Date closed. NULL = still operating. |
| `cc_open_date_sk` | INTEGER | FK → `date_dim`. Date opened. |
| `cc_name` | VARCHAR | Call centre name. |
| `cc_class` | VARCHAR | Classification (e.g. `large`, `medium`, `small`). |
| `cc_employees` | INTEGER | Number of employees. |
| `cc_sq_ft` | INTEGER | Floor area in square feet. |
| `cc_hours` | CHAR(20) | Operating hours. |
| `cc_manager` | VARCHAR | Manager name. |
| `cc_mkt_id` | INTEGER | Market group ID. |
| `cc_mkt_class` | CHAR(50) | Market class description. |
| `cc_mkt_desc` | VARCHAR | Market description. |
| `cc_market_manager` | VARCHAR | Market manager name. |
| `cc_division` | INTEGER | Division ID. |
| `cc_division_name` | VARCHAR | Division name. |
| `cc_company` | INTEGER | Company ID. |
| `cc_company_name` | CHAR(50) | Company name. |
| `cc_street_number` | CHAR(10) | Street number. |
| `cc_street_name` | VARCHAR | Street name. |
| `cc_street_type` | CHAR(15) | Street type. |
| `cc_suite_number` | CHAR(10) | Suite number. |
| `cc_city` | VARCHAR | City. |
| `cc_county` | VARCHAR | County. |
| `cc_state` | CHAR(2) | State code. |
| `cc_zip` | CHAR(10) | ZIP code. |
| `cc_country` | VARCHAR | Country. |
| `cc_gmt_offset` | NUMERIC | Timezone offset. |
| `cc_tax_percentage` | NUMERIC | Local tax rate applicable to this call centre. |

## Notes
- SCD Type 2: a call centre gets a new `cc_call_center_sk` when its attributes change.
- `cc_class` lets you segment by call centre size for volume analysis.
