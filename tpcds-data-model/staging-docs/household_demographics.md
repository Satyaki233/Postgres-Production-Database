# staging.household_demographics — Household Profiles

**Rows:** 7,200 | **Source:** `raw.household_demographics`

Household-level attributes — income band, buying potential, vehicle and dependant counts.
Referenced by sales tables as `*_hdemo_sk` and by `customer.c_current_hdemo_sk`.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `hd_demo_sk` | INTEGER | Surrogate key. Referenced as `c_current_hdemo_sk` in `customer`, and `ss_hdemo_sk`, `ws_bill_hdemo_sk`, etc. in sales. |
| `hd_income_band_sk` | INTEGER | FK → `income_band.ib_income_band_sk`. The income tier of this household. |
| `hd_buy_potential` | CHAR(15) | Buying potential band: `Unknown`, `0-500`, `501-1000`, `1001-5000`, `5001-10000`, `10001-20000`, `>10000`. |
| `hd_dep_count` | INTEGER | Number of dependants in the household. |
| `hd_vehicle_count` | INTEGER | Number of vehicles owned. |

## Notes
- 7,200 rows = all combinations of income band × buy potential × dep count × vehicle count.
- Not included in `marts.dim_customer` — join staging `household_demographics` and `income_band` when you need household income or vehicle data.
