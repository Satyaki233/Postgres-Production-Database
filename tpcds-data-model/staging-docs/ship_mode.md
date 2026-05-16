# staging.ship_mode — Shipping Method Lookup

**Rows:** 20 | **Source:** `raw.ship_mode`

A small lookup table for shipping methods. Referenced by `web_sales`, `catalog_sales`,
and `catalog_returns` via `*_ship_mode_sk`. No marts dimension — query staging directly.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `sm_ship_mode_sk` | INTEGER | Surrogate key. Referenced as `ws_ship_mode_sk`, `cs_ship_mode_sk`, `cr_ship_mode_sk`. |
| `sm_ship_mode_id` | CHAR(16) | Natural key. |
| `sm_type` | CHAR(30) | Shipping type (e.g. `LIBRARY`, `SURFACE`, `AIR`). |
| `sm_code` | CHAR(10) | Short code for the shipping method. |
| `sm_carrier` | CHAR(20) | Carrier name (e.g. `ORIENTAL`, `NAVAJO`). |
| `sm_contract` | CHAR(20) | Contract name for this shipping arrangement. |

## Notes
- Only used in web and catalog channels — store sales have no shipping method.
- Only 20 rows — always fits in memory.
