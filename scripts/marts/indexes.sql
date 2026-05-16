-- ==========================================
-- INDEXES ON MART TABLES
-- Run after data is loaded into marts
-- ==========================================

-- fact_store_sales
CREATE INDEX idx_fss_date      ON marts.fact_store_sales (ss_sold_date_sk);
CREATE INDEX idx_fss_customer  ON marts.fact_store_sales (ss_customer_sk);
CREATE INDEX idx_fss_item      ON marts.fact_store_sales (ss_item_sk);
CREATE INDEX idx_fss_store     ON marts.fact_store_sales (ss_store_sk);
CREATE INDEX idx_fss_promo     ON marts.fact_store_sales (ss_promo_sk);

-- fact_web_sales
CREATE INDEX idx_fws_date      ON marts.fact_web_sales (ws_sold_date_sk);
CREATE INDEX idx_fws_customer  ON marts.fact_web_sales (ws_bill_customer_sk);
CREATE INDEX idx_fws_item      ON marts.fact_web_sales (ws_item_sk);
CREATE INDEX idx_fws_promo     ON marts.fact_web_sales (ws_promo_sk);

-- fact_catalog_sales
CREATE INDEX idx_fcs_date      ON marts.fact_catalog_sales (cs_sold_date_sk);
CREATE INDEX idx_fcs_customer  ON marts.fact_catalog_sales (cs_bill_customer_sk);
CREATE INDEX idx_fcs_item      ON marts.fact_catalog_sales (cs_item_sk);
CREATE INDEX idx_fcs_promo     ON marts.fact_catalog_sales (cs_promo_sk);

-- dim_customer
CREATE INDEX idx_dc_demo       ON marts.dim_customer (cd_demo_sk);
CREATE INDEX idx_dc_addr       ON marts.dim_customer (ca_address_sk);

-- dim_item  (column names match create_marts.sql aliases)
CREATE INDEX idx_di_class      ON marts.dim_item (class);
CREATE INDEX idx_di_category   ON marts.dim_item (category);
CREATE INDEX idx_di_brand      ON marts.dim_item (brand);

-- dim_date  (column names match create_marts.sql aliases)
CREATE INDEX idx_dd_year       ON marts.dim_date (year);
CREATE INDEX idx_dd_month      ON marts.dim_date (month);
CREATE INDEX idx_dd_qoy        ON marts.dim_date (quarter);

-- ==========================================
-- ANALYZE (separate from VACUUM to avoid Docker shared-memory limits)
-- ==========================================
ANALYZE marts.fact_store_sales;
ANALYZE marts.fact_web_sales;
ANALYZE marts.fact_catalog_sales;
ANALYZE marts.dim_date;
ANALYZE marts.dim_customer;
ANALYZE marts.dim_item;
ANALYZE marts.dim_store;
ANALYZE marts.dim_promotion;
