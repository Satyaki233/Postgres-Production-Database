# staging.customer_address — Mailing Addresses

**Rows:** 250,000 | **Source:** `raw.customer_address`

Mailing addresses for customers. Each address is a standalone record referenced
by `customer.c_current_addr_sk`. A customer can have multiple historical addresses.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `ca_address_sk` | INTEGER | Surrogate key. Referenced as `c_current_addr_sk` in `customer`. |
| `ca_address_id` | TEXT | Natural key. 16-char identifier. |
| `ca_street_number` | TEXT | Street number (e.g. `12`). |
| `ca_street_name` | TEXT | Street name (e.g. `Oak`). |
| `ca_street_type` | TEXT | Street type abbreviation (`St`, `Ave`, `Blvd`, `Dr` …). |
| `ca_suite_number` | TEXT | Apartment / suite number (e.g. `Suite 100`). NULL if N/A. |
| `ca_city` | TEXT | City name. |
| `ca_county` | TEXT | County name. |
| `ca_state` | TEXT | Two-letter US state code. |
| `ca_zip` | TEXT | ZIP code (5-digit). |
| `ca_country` | TEXT | Country name (mostly `United States`). |
| `ca_gmt_offset` | NUMERIC | GMT timezone offset for this location. |
| `ca_location_type` | TEXT | Location type: `apartment`, `house`, `condo`, `unknown`. |

## Notes
- Fully denormalised into `marts.dim_customer` (city, state, zip, country, gmt_offset). Query staging when you need street-level detail or `ca_location_type`.
- `ca_gmt_offset` is useful for converting sale times to local time.
