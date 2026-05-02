# staging.income_band — Income Range Lookup

**Rows:** 20 | **Source:** `raw.income_band`

A small lookup table that maps income band keys to dollar ranges. Referenced by
`household_demographics.hd_income_band_sk`.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `ib_income_band_sk` | INTEGER | Surrogate key. Referenced as `hd_income_band_sk` in `household_demographics`. |
| `ib_lower_bound` | INTEGER | Lower bound of the income range in dollars. |
| `ib_upper_bound` | INTEGER | Upper bound of the income range in dollars. |

## Sample Rows
```
ib_income_band_sk | ib_lower_bound | ib_upper_bound
------------------+----------------+---------------
1                 | 0              | 10000
2                 | 10001          | 20000
...
20                | 190001         | 200000
```

## Notes
- Only 20 rows — fits entirely in memory.
- Join path to sales: `store_sales → customer → household_demographics → income_band`.
