# staging.web_site — Web Domains

**Rows:** 42 | **Source:** `raw.web_site`

Web site / domain records. Referenced by `web_sales` via `ws_web_site_sk`. Includes
corporate hierarchy, market info, and address. No marts dimension — query staging directly.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `web_site_sk` | INTEGER | Surrogate key. Referenced as `ws_web_site_sk` in `web_sales`. |
| `web_site_id` | CHAR(16) | Natural key. |
| `web_rec_start_date` | DATE | SCD Type 2 effective start date. |
| `web_rec_end_date` | DATE | SCD Type 2 end date. NULL = active. |
| `web_name` | VARCHAR | Site name (e.g. `aware site`). |
| `web_open_date_sk` | INTEGER | FK → `date_dim`. Date the site launched. |
| `web_close_date_sk` | INTEGER | FK → `date_dim`. Date the site closed. NULL = still active. |
| `web_class` | VARCHAR | Site classification. |
| `web_manager` | VARCHAR | Site manager name. |
| `web_mkt_id` | INTEGER | Market group ID. |
| `web_mkt_class` | VARCHAR | Market class. |
| `web_mkt_desc` | VARCHAR | Market description. |
| `web_market_manager` | VARCHAR | Market manager name. |
| `web_company_id` | INTEGER | Company ID. |
| `web_company_name` | CHAR(50) | Company name. |
| `web_street_number` | CHAR(10) | Street number of headquarters. |
| `web_street_name` | VARCHAR | Street name. |
| `web_street_type` | CHAR(15) | Street type. |
| `web_suite_number` | CHAR(10) | Suite number. |
| `web_city` | VARCHAR | City. |
| `web_county` | VARCHAR | County. |
| `web_state` | CHAR(2) | State code. |
| `web_zip` | CHAR(10) | ZIP code. |
| `web_country` | VARCHAR | Country. |
| `web_gmt_offset` | NUMERIC | Timezone offset. |
| `web_tax_percentage` | NUMERIC | Tax rate applicable to this site. |
