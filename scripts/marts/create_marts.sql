-- ==========================================
-- MARTS LAYER — Partitioned Facts + Conformed Dimensions
-- Run after staging/transform.sql completes.
-- ==========================================

SET search_path = marts, staging, public;

-- ==========================================
-- CONFORMED DIMENSIONS
-- ==========================================

-- dim_date: simplified calendar attributes used in every fact join
CREATE TABLE marts.dim_date AS
SELECT
    d_date_sk                              AS date_sk,
    d_date                                 AS full_date,
    d_year                                 AS year,
    d_qoy                                  AS quarter,
    d_moy                                  AS month,
    d_dom                                  AS day_of_month,
    d_dow                                  AS day_of_week,
    d_day_name                             AS day_name,
    d_week_seq                             AS week_seq,
    d_month_seq                            AS month_seq,
    d_quarter_seq                          AS quarter_seq,
    CASE WHEN d_holiday = 'Y' THEN true ELSE false END    AS is_holiday,
    CASE WHEN d_weekend = 'Y' THEN true ELSE false END    AS is_weekend,
    CASE WHEN d_current_year = 'Y' THEN true ELSE false END AS is_current_year
FROM staging.date_dim;

ALTER TABLE marts.dim_date ADD PRIMARY KEY (date_sk);

-- dim_customer: denormalised — customer + demographics + address
CREATE TABLE marts.dim_customer AS
SELECT
    c.c_customer_sk                        AS customer_sk,
    c.c_customer_id                        AS customer_id,
    c.c_first_name                         AS first_name,
    c.c_last_name                          AS last_name,
    c.c_salutation                         AS salutation,
    c.c_email_address                      AS email,
    c.c_preferred_cust_flag                AS preferred_flag,
    c.c_birth_year                         AS birth_year,
    c.c_birth_country                      AS birth_country,
    cd.cd_gender                           AS gender,
    cd.cd_marital_status                   AS marital_status,
    cd.cd_education_status                 AS education_status,
    cd.cd_purchase_estimate                AS purchase_estimate,
    cd.cd_credit_rating                    AS credit_rating,
    cd.cd_dep_count                        AS dep_count,
    ca.ca_city                             AS city,
    ca.ca_state                            AS state,
    ca.ca_zip                              AS zip,
    ca.ca_country                          AS country,
    ca.ca_gmt_offset                       AS gmt_offset,
    c.c_current_cdemo_sk                   AS cd_demo_sk,
    c.c_current_addr_sk                    AS ca_address_sk
FROM staging.customer          c
LEFT JOIN staging.customer_demographics cd ON c.c_current_cdemo_sk = cd.cd_demo_sk
LEFT JOIN staging.customer_address      ca ON c.c_current_addr_sk  = ca.ca_address_sk;

ALTER TABLE marts.dim_customer ADD PRIMARY KEY (customer_sk);

-- dim_item
CREATE TABLE marts.dim_item AS
SELECT
    i_item_sk         AS item_sk,
    i_item_id         AS item_id,
    i_product_name    AS product_name,
    i_brand           AS brand,
    i_brand_id        AS brand_id,
    i_class           AS class,
    i_class_id        AS class_id,
    i_category        AS category,
    i_category_id     AS category_id,
    i_manufact        AS manufacturer,
    i_manufact_id     AS manufacturer_id,
    i_size            AS size,
    i_color           AS color,
    i_units           AS units,
    i_container       AS container,
    i_current_price   AS current_price,
    i_wholesale_cost  AS wholesale_cost,
    i_rec_start_date  AS valid_from,
    i_rec_end_date    AS valid_to
FROM staging.item;

ALTER TABLE marts.dim_item ADD PRIMARY KEY (item_sk);

-- dim_store
CREATE TABLE marts.dim_store AS
SELECT
    s_store_sk         AS store_sk,
    s_store_id         AS store_id,
    s_store_name       AS store_name,
    s_number_employees AS employees,
    s_floor_space      AS floor_space,
    s_hours            AS hours,
    s_manager          AS manager,
    s_market_id        AS market_id,
    s_market_desc      AS market_desc,
    s_city             AS city,
    s_state            AS state,
    s_zip              AS zip,
    s_country          AS country,
    s_gmt_offset       AS gmt_offset,
    s_tax_precentage   AS tax_rate,
    s_rec_start_date   AS valid_from,
    s_rec_end_date     AS valid_to
FROM staging.store;

ALTER TABLE marts.dim_store ADD PRIMARY KEY (store_sk);

-- dim_promotion
CREATE TABLE marts.dim_promotion AS
SELECT
    p_promo_sk         AS promo_sk,
    p_promo_id         AS promo_id,
    p_promo_name       AS promo_name,
    p_purpose          AS purpose,
    p_cost             AS cost,
    p_response_target  AS response_target,
    p_channel_dmail    AS channel_dmail,
    p_channel_email    AS channel_email,
    p_channel_catalog  AS channel_catalog,
    p_channel_tv       AS channel_tv,
    p_channel_radio    AS channel_radio,
    p_channel_press    AS channel_press,
    p_channel_event    AS channel_event,
    p_channel_demo     AS channel_demo,
    p_discount_active  AS discount_active
FROM staging.promotion;

ALTER TABLE marts.dim_promotion ADD PRIMARY KEY (promo_sk);

-- ==========================================
-- PARTITIONED FACT TABLES
-- Partitioned by date_sk (RANGE), with a DEFAULT partition to catch all data.
-- pg_partman manages ongoing partition creation via cron job.
-- ==========================================

-- fact_store_sales (~28M rows at SF10)
CREATE TABLE marts.fact_store_sales (
    ss_sold_date_sk       INTEGER,
    ss_sold_time_sk       INTEGER,
    ss_item_sk            INTEGER       NOT NULL,
    ss_customer_sk        INTEGER,
    ss_store_sk           INTEGER,
    ss_promo_sk           INTEGER,
    ss_ticket_number      BIGINT        NOT NULL,
    ss_quantity           INTEGER,
    ss_wholesale_cost     NUMERIC(7,2),
    ss_list_price         NUMERIC(7,2),
    ss_sales_price        NUMERIC(7,2),
    ss_ext_discount_amt   NUMERIC(7,2),
    ss_ext_sales_price    NUMERIC(7,2),
    ss_ext_wholesale_cost NUMERIC(7,2),
    ss_ext_list_price     NUMERIC(7,2),
    ss_ext_tax            NUMERIC(7,2),
    ss_coupon_amt         NUMERIC(7,2),
    ss_net_paid           NUMERIC(7,2),
    ss_net_paid_inc_tax   NUMERIC(7,2),
    ss_net_profit         NUMERIC(7,2)
) PARTITION BY RANGE (ss_sold_date_sk);

CREATE TABLE marts.fact_store_sales_default
    PARTITION OF marts.fact_store_sales DEFAULT;

INSERT INTO marts.fact_store_sales (
    ss_sold_date_sk, ss_sold_time_sk, ss_item_sk, ss_customer_sk,
    ss_store_sk, ss_promo_sk, ss_ticket_number, ss_quantity,
    ss_wholesale_cost, ss_list_price, ss_sales_price, ss_ext_discount_amt,
    ss_ext_sales_price, ss_ext_wholesale_cost, ss_ext_list_price, ss_ext_tax,
    ss_coupon_amt, ss_net_paid, ss_net_paid_inc_tax, ss_net_profit
)
SELECT
    ss_sold_date_sk, ss_sold_time_sk, ss_item_sk, ss_customer_sk,
    ss_store_sk, ss_promo_sk, ss_ticket_number, ss_quantity,
    ss_wholesale_cost, ss_list_price, ss_sales_price, ss_ext_discount_amt,
    ss_ext_sales_price, ss_ext_wholesale_cost, ss_ext_list_price, ss_ext_tax,
    ss_coupon_amt, ss_net_paid, ss_net_paid_inc_tax, ss_net_profit
FROM staging.store_sales;

-- fact_web_sales (~7M rows at SF10)
CREATE TABLE marts.fact_web_sales (
    ws_sold_date_sk           INTEGER,
    ws_sold_time_sk           INTEGER,
    ws_item_sk                INTEGER       NOT NULL,
    ws_bill_customer_sk       INTEGER,
    ws_ship_customer_sk       INTEGER,
    ws_web_page_sk            INTEGER,
    ws_web_site_sk            INTEGER,
    ws_promo_sk               INTEGER,
    ws_order_number           BIGINT        NOT NULL,
    ws_quantity               INTEGER,
    ws_wholesale_cost         NUMERIC(7,2),
    ws_list_price             NUMERIC(7,2),
    ws_sales_price            NUMERIC(7,2),
    ws_ext_discount_amt       NUMERIC(7,2),
    ws_ext_sales_price        NUMERIC(7,2),
    ws_ext_wholesale_cost     NUMERIC(7,2),
    ws_ext_list_price         NUMERIC(7,2),
    ws_ext_tax                NUMERIC(7,2),
    ws_coupon_amt             NUMERIC(7,2),
    ws_ext_ship_cost          NUMERIC(7,2),
    ws_net_paid               NUMERIC(7,2),
    ws_net_paid_inc_tax       NUMERIC(7,2),
    ws_net_paid_inc_ship      NUMERIC(7,2),
    ws_net_paid_inc_ship_tax  NUMERIC(7,2),
    ws_net_profit             NUMERIC(7,2)
) PARTITION BY RANGE (ws_sold_date_sk);

CREATE TABLE marts.fact_web_sales_default
    PARTITION OF marts.fact_web_sales DEFAULT;

INSERT INTO marts.fact_web_sales (
    ws_sold_date_sk, ws_sold_time_sk, ws_item_sk, ws_bill_customer_sk,
    ws_ship_customer_sk, ws_web_page_sk, ws_web_site_sk, ws_promo_sk,
    ws_order_number, ws_quantity, ws_wholesale_cost, ws_list_price,
    ws_sales_price, ws_ext_discount_amt, ws_ext_sales_price, ws_ext_wholesale_cost,
    ws_ext_list_price, ws_ext_tax, ws_coupon_amt, ws_ext_ship_cost,
    ws_net_paid, ws_net_paid_inc_tax, ws_net_paid_inc_ship, ws_net_paid_inc_ship_tax,
    ws_net_profit
)
SELECT
    ws_sold_date_sk, ws_sold_time_sk, ws_item_sk, ws_bill_customer_sk,
    ws_ship_customer_sk, ws_web_page_sk, ws_web_site_sk, ws_promo_sk,
    ws_order_number, ws_quantity, ws_wholesale_cost, ws_list_price,
    ws_sales_price, ws_ext_discount_amt, ws_ext_sales_price, ws_ext_wholesale_cost,
    ws_ext_list_price, ws_ext_tax, ws_coupon_amt, ws_ext_ship_cost,
    ws_net_paid, ws_net_paid_inc_tax, ws_net_paid_inc_ship, ws_net_paid_inc_ship_tax,
    ws_net_profit
FROM staging.web_sales;

-- fact_catalog_sales (~14M rows at SF10)
CREATE TABLE marts.fact_catalog_sales (
    cs_sold_date_sk           INTEGER,
    cs_sold_time_sk           INTEGER,
    cs_item_sk                INTEGER       NOT NULL,
    cs_bill_customer_sk       INTEGER,
    cs_ship_customer_sk       INTEGER,
    cs_call_center_sk         INTEGER,
    cs_catalog_page_sk        INTEGER,
    cs_promo_sk               INTEGER,
    cs_order_number           BIGINT        NOT NULL,
    cs_quantity               INTEGER,
    cs_wholesale_cost         NUMERIC(7,2),
    cs_list_price             NUMERIC(7,2),
    cs_sales_price            NUMERIC(7,2),
    cs_ext_discount_amt       NUMERIC(7,2),
    cs_ext_sales_price        NUMERIC(7,2),
    cs_ext_wholesale_cost     NUMERIC(7,2),
    cs_ext_list_price         NUMERIC(7,2),
    cs_ext_tax                NUMERIC(7,2),
    cs_coupon_amt             NUMERIC(7,2),
    cs_ext_ship_cost          NUMERIC(7,2),
    cs_net_paid               NUMERIC(7,2),
    cs_net_paid_inc_tax       NUMERIC(7,2),
    cs_net_paid_inc_ship      NUMERIC(7,2),
    cs_net_paid_inc_ship_tax  NUMERIC(7,2),
    cs_net_profit             NUMERIC(7,2)
) PARTITION BY RANGE (cs_sold_date_sk);

CREATE TABLE marts.fact_catalog_sales_default
    PARTITION OF marts.fact_catalog_sales DEFAULT;

INSERT INTO marts.fact_catalog_sales (
    cs_sold_date_sk, cs_sold_time_sk, cs_item_sk, cs_bill_customer_sk,
    cs_ship_customer_sk, cs_call_center_sk, cs_catalog_page_sk, cs_promo_sk,
    cs_order_number, cs_quantity, cs_wholesale_cost, cs_list_price,
    cs_sales_price, cs_ext_discount_amt, cs_ext_sales_price, cs_ext_wholesale_cost,
    cs_ext_list_price, cs_ext_tax, cs_coupon_amt, cs_ext_ship_cost,
    cs_net_paid, cs_net_paid_inc_tax, cs_net_paid_inc_ship, cs_net_paid_inc_ship_tax,
    cs_net_profit
)
SELECT
    cs_sold_date_sk, cs_sold_time_sk, cs_item_sk, cs_bill_customer_sk,
    cs_ship_customer_sk, cs_call_center_sk, cs_catalog_page_sk, cs_promo_sk,
    cs_order_number, cs_quantity, cs_wholesale_cost, cs_list_price,
    cs_sales_price, cs_ext_discount_amt, cs_ext_sales_price, cs_ext_wholesale_cost,
    cs_ext_list_price, cs_ext_tax, cs_coupon_amt, cs_ext_ship_cost,
    cs_net_paid, cs_net_paid_inc_tax, cs_net_paid_inc_ship, cs_net_paid_inc_ship_tax,
    cs_net_profit
FROM staging.catalog_sales;
