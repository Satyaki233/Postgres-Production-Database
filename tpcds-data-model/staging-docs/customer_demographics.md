# staging.customer_demographics — Demographic Profiles

**Rows:** 1,920,800 | **Source:** `raw.customer_demographics`

Contains all possible combinations of demographic attributes — gender, marital status,
education, credit rating, and dependant counts. This is a **type 2 style table**: a customer
can have multiple rows here over time as their demographics change.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `cd_demo_sk` | INTEGER | Surrogate key. Referenced as `c_current_cdemo_sk` in `customer`, and `ss_cdemo_sk`, `ws_bill_cdemo_sk`, etc. in sales tables. |
| `cd_gender` | CHAR(1) | `M` = Male, `F` = Female. |
| `cd_marital_status` | CHAR(1) | `S` Single, `M` Married, `D` Divorced, `W` Widowed, `U` Unknown. |
| `cd_education_status` | CHAR(20) | `Unknown`, `2 yr Degree`, `4 yr Degree`, `College`, `Advanced Degree`, `Primary`, `Secondary`. |
| `cd_purchase_estimate` | INTEGER | Estimated annual spend in dollars (0–10,000 in $500 steps). |
| `cd_credit_rating` | CHAR(10) | `Good`, `High Risk`, `Low Risk`, `Unknown`. |
| `cd_dep_count` | INTEGER | Number of financial dependants. |
| `cd_dep_employed_count` | INTEGER | Number of employed dependants. |
| `cd_dep_college_count` | INTEGER | Number of dependants in college. |

## Notes
- 1.92M rows is much larger than the 500K customer rows because TPC-DS pre-generates all permutations of demographic combinations.
- `cd_dep_employed_count` and `cd_dep_college_count` are subsets of `cd_dep_count`.
- This table is fully denormalised into `marts.dim_customer` — no need to join it separately for reporting.
