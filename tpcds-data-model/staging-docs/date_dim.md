# staging.date_dim — Calendar Dimension

**Rows:** 73,049 | **Source:** `raw.date_dim`

The full TPC-DS calendar. Contains 28 attributes per date covering fiscal year, sequences,
flags, and current-period markers. The marts layer promotes a simplified 14-column version
as `marts.dim_date` — use staging when you need fiscal year attributes or raw flag characters.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `d_date_sk` | INTEGER | Surrogate key. Julian day number. Referenced in all sales/returns tables. |
| `d_date_id` | TEXT | Natural key. 16-char identifier. |
| `d_date` | DATE | Calendar date. |
| `d_month_seq` | INTEGER | Sequential month number from TPC-DS epoch. |
| `d_week_seq` | INTEGER | Sequential week number. |
| `d_quarter_seq` | INTEGER | Sequential quarter number. |
| `d_year` | INTEGER | Four-digit year. |
| `d_dow` | INTEGER | Day of week (0=Sunday … 6=Saturday). |
| `d_moy` | INTEGER | Month of year (1–12). |
| `d_dom` | INTEGER | Day of month (1–31). |
| `d_qoy` | INTEGER | Quarter of year (1–4). |
| `d_fy_year` | INTEGER | Fiscal year. |
| `d_fy_quarter_seq` | INTEGER | Fiscal quarter sequence number. |
| `d_fy_week_seq` | INTEGER | Fiscal week sequence number. |
| `d_day_name` | TEXT | Day name (`Monday`, `Tuesday` …). |
| `d_quarter_name` | TEXT | Quarter label (e.g. `2001Q1`). |
| `d_holiday` | CHAR(1) | `Y` = public holiday. |
| `d_weekend` | CHAR(1) | `Y` = Saturday or Sunday. |
| `d_following_holiday` | CHAR(1) | `Y` = the day immediately before a public holiday. |
| `d_first_dom` | INTEGER | `d_date_sk` of the first day of this month. |
| `d_last_dom` | INTEGER | `d_date_sk` of the last day of this month. |
| `d_same_day_ly` | INTEGER | `d_date_sk` of the same day last year. |
| `d_same_day_lq` | INTEGER | `d_date_sk` of the same day last quarter. |
| `d_current_day` | CHAR(1) | `Y` = this is today in the dataset. |
| `d_current_week` | CHAR(1) | `Y` = falls in the current week of the dataset. |
| `d_current_month` | CHAR(1) | `Y` = falls in the current month. |
| `d_current_quarter` | CHAR(1) | `Y` = falls in the current quarter. |
| `d_current_year` | CHAR(1) | `Y` = falls in the current fiscal year. |

## Notes
- `d_same_day_ly` and `d_same_day_lq` are pre-computed self-join keys — use them for year-over-year comparisons without a self-join.
- Marts alias: `d_year` → `year`, `d_moy` → `month`, `d_qoy` → `quarter`.
- Fiscal year columns (`d_fy_*`) are not in `marts.dim_date` — query staging if needed.
