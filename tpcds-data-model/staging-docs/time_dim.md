# staging.time_dim — Time of Day Dimension

**Rows:** 86,400 | **Source:** `raw.time_dim`

One row per second of the day (86,400 seconds = 24 hours). Used by sales and returns
tables via `*_sold_time_sk` / `*_return_time_sk`. No marts dimension was created for
this table — query staging directly when you need time-of-day analysis.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `t_time_sk` | INTEGER | Surrogate key. Second of the day (0–86399). |
| `t_time_id` | TEXT | Natural key. 16-char identifier. |
| `t_time` | INTEGER | Same as `t_time_sk` — seconds since midnight. |
| `t_hour` | INTEGER | Hour of day (0–23). |
| `t_minute` | INTEGER | Minute within the hour (0–59). |
| `t_second` | INTEGER | Second within the minute (0–59). |
| `t_am_pm` | TEXT | `AM` or `PM`. |
| `t_shift` | TEXT | Work shift: `first` (6am–2pm), `second` (2pm–10pm), `third` (10pm–6am). |
| `t_sub_shift` | TEXT | Sub-shift: `morning`, `afternoon`, `evening`, `night`. |
| `t_meal_time` | TEXT | Meal period for relevant hours: `breakfast`, `lunch`, `dinner`. NULL otherwise. |

## Notes
- `t_meal_time` is NULL for most rows — only populated during typical meal hours.
- Join on `ss_sold_time_sk = t_time_sk` for store sales, `ws_sold_time_sk` for web sales.

## Sample Query
```sql
-- Sales by shift
SELECT t.t_shift, COUNT(*) AS transactions, SUM(ss_net_paid) AS revenue
FROM staging.store_sales s
JOIN staging.time_dim t ON s.ss_sold_time_sk = t.t_time_sk
GROUP BY t.t_shift
ORDER BY revenue DESC;
```
