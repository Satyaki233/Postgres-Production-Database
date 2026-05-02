-- ==========================================
-- RAW → STAGING TRANSFORM
-- Cleans up dsdgen artifacts; adds NOT NULL where guaranteed by spec.
-- Run after tpcds/load.sh completes.
-- ==========================================

SET search_path = staging, raw, public;

-- ── Dimensions ────────────────────────────────────────────────────────────────

CREATE TABLE staging.date_dim AS
SELECT
    d_date_sk,
    TRIM(d_date_id)                   AS d_date_id,
    d_date,
    d_month_seq,
    d_week_seq,
    d_quarter_seq,
    d_year,
    d_dow,
    d_moy,
    d_dom,
    d_qoy,
    d_fy_year,
    d_fy_quarter_seq,
    d_fy_week_seq,
    TRIM(d_day_name)                  AS d_day_name,
    TRIM(d_quarter_name)              AS d_quarter_name,
    d_holiday,
    d_weekend,
    d_following_holiday,
    d_first_dom,
    d_last_dom,
    d_same_day_ly,
    d_same_day_lq,
    d_current_day,
    d_current_week,
    d_current_month,
    d_current_quarter,
    d_current_year
FROM raw.date_dim
WHERE d_date_sk IS NOT NULL;

CREATE TABLE staging.time_dim AS
SELECT
    t_time_sk,
    TRIM(t_time_id)    AS t_time_id,
    t_time,
    t_hour,
    t_minute,
    t_second,
    TRIM(t_am_pm)      AS t_am_pm,
    TRIM(t_shift)      AS t_shift,
    TRIM(t_sub_shift)  AS t_sub_shift,
    TRIM(t_meal_time)  AS t_meal_time
FROM raw.time_dim
WHERE t_time_sk IS NOT NULL;

CREATE TABLE staging.customer AS
SELECT
    c_customer_sk,
    TRIM(c_customer_id)           AS c_customer_id,
    c_current_cdemo_sk,
    c_current_hdemo_sk,
    c_current_addr_sk,
    c_first_shipto_date_sk,
    c_first_sales_date_sk,
    TRIM(c_salutation)            AS c_salutation,
    TRIM(c_first_name)            AS c_first_name,
    TRIM(c_last_name)             AS c_last_name,
    c_preferred_cust_flag,
    c_birth_day,
    c_birth_month,
    c_birth_year,
    NULLIF(TRIM(c_birth_country), '')  AS c_birth_country,
    NULLIF(TRIM(c_login), '')          AS c_login,
    NULLIF(TRIM(c_email_address), '')  AS c_email_address,
    c_last_review_date_sk
FROM raw.customer
WHERE c_customer_sk IS NOT NULL;

CREATE TABLE staging.customer_demographics AS
SELECT * FROM raw.customer_demographics
WHERE cd_demo_sk IS NOT NULL;

CREATE TABLE staging.customer_address AS
SELECT
    ca_address_sk,
    TRIM(ca_address_id)          AS ca_address_id,
    NULLIF(TRIM(ca_street_number), '') AS ca_street_number,
    NULLIF(TRIM(ca_street_name), '')   AS ca_street_name,
    NULLIF(TRIM(ca_street_type), '')   AS ca_street_type,
    NULLIF(TRIM(ca_suite_number), '')  AS ca_suite_number,
    NULLIF(TRIM(ca_city), '')          AS ca_city,
    NULLIF(TRIM(ca_county), '')        AS ca_county,
    NULLIF(TRIM(ca_state), '')         AS ca_state,
    NULLIF(TRIM(ca_zip), '')           AS ca_zip,
    NULLIF(TRIM(ca_country), '')       AS ca_country,
    ca_gmt_offset,
    NULLIF(TRIM(ca_location_type), '') AS ca_location_type
FROM raw.customer_address
WHERE ca_address_sk IS NOT NULL;

CREATE TABLE staging.item AS
SELECT
    i_item_sk,
    TRIM(i_item_id)               AS i_item_id,
    i_rec_start_date,
    i_rec_end_date,
    NULLIF(TRIM(i_item_desc), '') AS i_item_desc,
    i_current_price,
    i_wholesale_cost,
    i_brand_id,
    TRIM(i_brand)                 AS i_brand,
    i_class_id,
    TRIM(i_class)                 AS i_class,
    i_category_id,
    TRIM(i_category)              AS i_category,
    i_manufact_id,
    TRIM(i_manufact)              AS i_manufact,
    TRIM(i_size)                  AS i_size,
    TRIM(i_formulation)           AS i_formulation,
    TRIM(i_color)                 AS i_color,
    TRIM(i_units)                 AS i_units,
    TRIM(i_container)             AS i_container,
    i_manager_id,
    TRIM(i_product_name)          AS i_product_name
FROM raw.item
WHERE i_item_sk IS NOT NULL;

CREATE TABLE staging.store AS
SELECT * FROM raw.store WHERE s_store_sk IS NOT NULL;

CREATE TABLE staging.promotion AS
SELECT * FROM raw.promotion WHERE p_promo_sk IS NOT NULL;

CREATE TABLE staging.household_demographics AS
SELECT * FROM raw.household_demographics WHERE hd_demo_sk IS NOT NULL;

CREATE TABLE staging.web_site AS
SELECT * FROM raw.web_site WHERE web_site_sk IS NOT NULL;

CREATE TABLE staging.web_page AS
SELECT * FROM raw.web_page WHERE wp_web_page_sk IS NOT NULL;

CREATE TABLE staging.warehouse AS
SELECT * FROM raw.warehouse WHERE w_warehouse_sk IS NOT NULL;

CREATE TABLE staging.ship_mode AS
SELECT * FROM raw.ship_mode WHERE sm_ship_mode_sk IS NOT NULL;

CREATE TABLE staging.reason AS
SELECT *, TRIM(r_reason_desc) AS r_reason_desc_clean FROM raw.reason
WHERE r_reason_sk IS NOT NULL;

CREATE TABLE staging.income_band AS
SELECT * FROM raw.income_band WHERE ib_income_band_sk IS NOT NULL;

CREATE TABLE staging.call_center AS
SELECT * FROM raw.call_center WHERE cc_call_center_sk IS NOT NULL;

CREATE TABLE staging.catalog_page AS
SELECT * FROM raw.catalog_page WHERE cp_catalog_page_sk IS NOT NULL;

-- ── Fact tables ───────────────────────────────────────────────────────────────
-- Filter out rows with null mandatory keys (spec says they must be non-null).

CREATE TABLE staging.store_sales AS
SELECT * FROM raw.store_sales
WHERE ss_item_sk IS NOT NULL AND ss_ticket_number IS NOT NULL;

CREATE TABLE staging.store_returns AS
SELECT * FROM raw.store_returns
WHERE sr_item_sk IS NOT NULL AND sr_ticket_number IS NOT NULL;

CREATE TABLE staging.web_sales AS
SELECT * FROM raw.web_sales
WHERE ws_item_sk IS NOT NULL AND ws_order_number IS NOT NULL;

CREATE TABLE staging.web_returns AS
SELECT * FROM raw.web_returns
WHERE wr_item_sk IS NOT NULL AND wr_order_number IS NOT NULL;

CREATE TABLE staging.catalog_sales AS
SELECT * FROM raw.catalog_sales
WHERE cs_item_sk IS NOT NULL AND cs_order_number IS NOT NULL;

CREATE TABLE staging.catalog_returns AS
SELECT * FROM raw.catalog_returns
WHERE cr_item_sk IS NOT NULL AND cr_order_number IS NOT NULL;

CREATE TABLE staging.inventory AS
SELECT * FROM raw.inventory
WHERE inv_date_sk IS NOT NULL AND inv_item_sk IS NOT NULL;

-- ── Analyze ───────────────────────────────────────────────────────────────────
ANALYZE staging.store_sales;
ANALYZE staging.web_sales;
ANALYZE staging.catalog_sales;
ANALYZE staging.date_dim;
ANALYZE staging.customer;
ANALYZE staging.item;
