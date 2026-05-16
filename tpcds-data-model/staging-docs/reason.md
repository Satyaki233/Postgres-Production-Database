# staging.reason — Return Reason Codes

**Rows:** 45 | **Source:** `raw.reason`

Lookup table for return reasons. Referenced by `store_returns`, `catalog_returns`,
and `web_returns` via `*_reason_sk`. No marts dimension — query staging directly.

## Columns

| Column                | Type      | Description                                                                      |
| --------------------- | --------- | -------------------------------------------------------------------------------- |
| `r_reason_sk`         | INTEGER   | Surrogate key. Referenced as `sr_reason_sk`, `cr_reason_sk`, `wr_reason_sk`.     |
| `r_reason_id`         | CHAR(16)  | Natural key.                                                                     |
| `r_reason_desc`       | CHAR(100) | Raw reason description from TPC-DS (may contain leading/trailing spaces in raw). |
| `r_reason_desc_clean` | TEXT      | Trimmed version of the description. Added by staging transform.                  |

## Sample Values

```
Did not fit
Not compatible with existing equipment
Unacceptable quality
Found a better price
No longer needed
```

## Sample Query

```sql
-- Top return reasons by volume
SELECT r.r_reason_desc_clean, COUNT(*) AS returns
FROM staging.store_returns sr
JOIN staging.reason r ON sr.sr_reason_sk = r.r_reason_sk
GROUP BY r.r_reason_desc_clean
ORDER BY returns DESC;
```

## Notes

- `r_reason_desc_clean` is a staging-added column (TRIM of `r_reason_desc`) — not present in raw.
