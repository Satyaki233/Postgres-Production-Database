-- Load fact tables into marts.
-- Run after create_marts.sql has created the dimension tables.
-- Disables parallelism to stay within Docker memory limits.

SET search_path = marts, staging, public;
SET max_parallel_workers_per_gather = 0;
SET max_parallel_workers = 0;

-- ── fact_store_sales (~28M rows) ──────────────────────────────────────────────
DROP TABLE IF EXISTS marts.fact_store_sales CASCADE;

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

-- ── fact_web_sales (~7M rows) ─────────────────────────────────────────────────
DROP TABLE IF EXISTS marts.fact_web_sales CASCADE;

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

-- ── fact_catalog_sales (~14M rows) ────────────────────────────────────────────
DROP TABLE IF EXISTS marts.fact_catalog_sales CASCADE;

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
