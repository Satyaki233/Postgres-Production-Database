# staging.customer — Customer Master

**Rows:** 500,000 | **Source:** `raw.customer`

Customer master records. Contains foreign keys to three separate tables —
`customer_demographics`, `customer_address`, and `household_demographics` —
which are joined together in `marts.dim_customer`.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `c_customer_sk` | INTEGER | Surrogate key. Referenced in all sales/returns tables. |
| `c_customer_id` | TEXT | Natural key. 16-char source system ID. |
| `c_current_cdemo_sk` | INTEGER | FK → `customer_demographics.cd_demo_sk`. Current demographic profile. |
| `c_current_hdemo_sk` | INTEGER | FK → `household_demographics.hd_demo_sk`. Current household profile. |
| `c_current_addr_sk` | INTEGER | FK → `customer_address.ca_address_sk`. Current mailing address. |
| `c_first_shipto_date_sk` | INTEGER | FK → `date_dim.d_date_sk`. Date of first shipment to this customer. |
| `c_first_sales_date_sk` | INTEGER | FK → `date_dim.d_date_sk`. Date of first sale to this customer. |
| `c_salutation` | TEXT | Title: `Mr.`, `Mrs.`, `Dr.`, `Miss`, `Sir` … |
| `c_first_name` | TEXT | First name. |
| `c_last_name` | TEXT | Last name. |
| `c_preferred_cust_flag` | CHAR(1) | `Y` = loyalty / preferred member. |
| `c_birth_day` | INTEGER | Day of birth (1–31). |
| `c_birth_month` | INTEGER | Month of birth (1–12). |
| `c_birth_year` | INTEGER | Year of birth. |
| `c_birth_country` | TEXT | Country of birth. |
| `c_login` | TEXT | Login identifier (mostly NULL in TPC-DS data). |
| `c_email_address` | TEXT | Email address. |
| `c_last_review_date_sk` | INTEGER | FK → `date_dim.d_date_sk`. Date of last account review. |

## Relationship to Marts
`marts.dim_customer` joins this table with `customer_demographics` and `customer_address`
into one wide row. Use marts for reporting. Use staging when you need `c_current_hdemo_sk`,
`c_first_shipto_date_sk`, `c_first_sales_date_sk`, or `c_last_review_date_sk`.

## Notes
- A customer can have multiple historical demographic and address records — the `c_current_*_sk` columns point to the active one.
- `c_birth_day`, `c_birth_month`, `c_birth_year` are separate columns — combine them with `MAKE_DATE(c_birth_year, c_birth_month, c_birth_day)` to get a full birthdate.
