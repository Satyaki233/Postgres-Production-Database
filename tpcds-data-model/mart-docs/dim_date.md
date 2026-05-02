# dim_date — Calendar Dimension

**Schema:** marts | **Rows:** 73,049 | **Primary Key:** `date_sk`  
**Source:** `staging.date_dim` → `raw.date_dim`

---

## Purpose

Provides calendar attributes so analysts can slice any fact table by year, quarter,
month, day, holiday, or weekend without writing date arithmetic in SQL.

Every fact table joins here on its `*_sold_date_sk` column.

---

## Columns

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `date_sk` | INTEGER | NOT NULL | **Surrogate key.** Julian day number (e.g. 2451545 = 2000-01-01). Referenced in every fact table. |
| `full_date` | DATE | YES | Human-readable calendar date. Use this for display and arithmetic — never `date_sk`. |
| `year` | INTEGER | YES | Four-digit year (e.g. 2001). |
| `quarter` | INTEGER | YES | Quarter of year: 1–4. |
| `month` | INTEGER | YES | Month number: 1–12. |
| `day_of_month` | INTEGER | YES | Day within the month: 1–31. |
| `day_of_week` | INTEGER | YES | Day of week: 0 = Sunday … 6 = Saturday. |
| `day_name` | TEXT | YES | Name of the day (`Monday`, `Tuesday` …). |
| `week_seq` | INTEGER | YES | Sequential week number from the start of the TPC-DS calendar. |
| `month_seq` | INTEGER | YES | Sequential month number from the start of the TPC-DS calendar. |
| `quarter_seq` | INTEGER | YES | Sequential quarter number from the start of the TPC-DS calendar. |
| `is_holiday` | BOOLEAN | YES | `true` if this date is a public holiday. |
| `is_weekend` | BOOLEAN | YES | `true` if Saturday or Sunday. |
| `is_current_year` | BOOLEAN | YES | `true` if the date falls in the current fiscal year of the dataset. |

---

## Indexes

`year`, `month`, `quarter`

---

## Example Row

```
date_sk         2451911
full_date       2001-01-01
year            2001
quarter         1
month           1
day_of_month    1
day_of_week     1
day_name        Monday
is_holiday      false
is_weekend      false
is_current_year false
```

---

## Sample Queries

**Monthly revenue trend:**
```sql
SELECT d.year, d.month, SUM(ss_net_paid) AS revenue
FROM marts.fact_store_sales f
JOIN marts.dim_date d ON f.ss_sold_date_sk = d.date_sk
GROUP BY d.year, d.month
ORDER BY d.year, d.month;
```

**Holiday vs non-holiday sales:**
```sql
SELECT d.is_holiday, COUNT(*) AS transactions, SUM(ss_net_paid) AS revenue
FROM marts.fact_store_sales f
JOIN marts.dim_date d ON f.ss_sold_date_sk = d.date_sk
GROUP BY d.is_holiday;
```

---

## Notes

- `date_sk` is a Julian day number, not a 1-based sequence. Never do arithmetic on it — use `full_date`.
- The TPC-DS date range spans roughly 1998–2003. `is_current_year` is relative to the dataset, not today.
- A NULL `ss_sold_date_sk` in a fact row means the sale date is unknown. Use `LEFT JOIN` if you want to keep those rows.
