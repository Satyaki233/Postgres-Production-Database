-- ==========================================
-- Data Warehouse Analytical Queries
-- Target: marts schema (fact_store_sales, fact_web_sales,
--         fact_catalog_sales, dim_date, dim_customer, dim_item,
--         dim_store, dim_promotion)
-- ==========================================

SET search_path = marts, public;

-- ==========================================
-- Q1: Annual revenue by sales channel
-- Compare store, web, and catalog channels year-over-year.
-- ==========================================

SELECT
    d.year,
    ROUND(SUM(s.ss_net_paid)::numeric / 1e6, 2)  AS store_net_paid_M,
    ROUND(SUM(w.ws_net_paid)::numeric / 1e6, 2)  AS web_net_paid_M,
    ROUND(SUM(c.cs_net_paid)::numeric / 1e6, 2)  AS catalog_net_paid_M,
    ROUND(
        (SUM(s.ss_net_paid) + SUM(w.ws_net_paid) + SUM(c.cs_net_paid))::numeric / 1e6,
    2) AS total_net_paid_M
FROM dim_date d
LEFT JOIN fact_store_sales   s ON s.ss_sold_date_sk  = d.date_sk
LEFT JOIN fact_web_sales      w ON w.ws_sold_date_sk  = d.date_sk
LEFT JOIN fact_catalog_sales  c ON c.cs_sold_date_sk  = d.date_sk
WHERE d.year BETWEEN 1998 AND 2002
GROUP BY d.year
ORDER BY d.year;


-- ==========================================
-- Q2: Top 10 product categories by net profit (store channel)
-- Which categories drive the most profit?
-- ==========================================

SELECT
    i.category,
    COUNT(*)                                          AS transactions,
    ROUND(SUM(f.ss_net_paid)::numeric   / 1e6, 2)   AS net_paid_M,
    ROUND(SUM(f.ss_net_profit)::numeric / 1e6, 2)   AS net_profit_M,
    ROUND(
        100.0 * SUM(f.ss_net_profit) / NULLIF(SUM(f.ss_net_paid), 0),
    2)                                                AS profit_margin_pct
FROM fact_store_sales f
JOIN dim_item i ON f.ss_item_sk = i.item_sk
GROUP BY i.category
ORDER BY net_profit_M DESC
LIMIT 10;


-- ==========================================
-- Q3: Store performance ranking
-- Rank every store by net profit; include profit margin and
-- avg transaction value to distinguish high-volume vs high-margin stores.
-- ==========================================

SELECT
    s.store_sk,
    s.store_name,
    s.city,
    s.state,
    COUNT(*)                                              AS transactions,
    ROUND(SUM(f.ss_net_paid)::numeric   / 1e6, 2)       AS net_paid_M,
    ROUND(SUM(f.ss_net_profit)::numeric / 1e6, 2)       AS net_profit_M,
    ROUND(
        100.0 * SUM(f.ss_net_profit) / NULLIF(SUM(f.ss_net_paid), 0),
    2)                                                    AS profit_margin_pct,
    ROUND(AVG(f.ss_net_paid)::numeric, 2)                AS avg_txn_value,
    RANK() OVER (ORDER BY SUM(f.ss_net_profit) DESC)     AS profit_rank
FROM fact_store_sales f
JOIN dim_store s ON f.ss_store_sk = s.store_sk
GROUP BY s.store_sk, s.store_name, s.city, s.state
ORDER BY profit_rank
LIMIT 20;


-- ==========================================
-- Q4: Customer segments — revenue by credit rating and gender
-- Which demographic segment spends the most?
-- ==========================================

SELECT
    c.credit_rating,
    c.gender,
    COUNT(DISTINCT f.ss_customer_sk)              AS unique_customers,
    COUNT(*)                                      AS transactions,
    ROUND(SUM(f.ss_net_paid)::numeric / 1e6, 2)  AS net_paid_M,
    ROUND(AVG(f.ss_net_paid)::numeric, 2)         AS avg_spend_per_txn
FROM fact_store_sales f
JOIN dim_customer c ON f.ss_customer_sk = c.customer_sk
WHERE c.credit_rating IS NOT NULL
  AND c.gender        IS NOT NULL
GROUP BY c.credit_rating, c.gender
ORDER BY net_paid_M DESC;


-- ==========================================
-- Q5: Promotion effectiveness
-- For each promotion, compare promoted vs baseline revenue and
-- calculate the revenue lift it generates per dollar of promo cost.
-- ==========================================

WITH promo_sales AS (
    SELECT
        p.promo_sk,
        p.promo_name,
        p.purpose,
        p.cost                                            AS promo_cost,
        COUNT(*)                                          AS transactions,
        ROUND(SUM(f.ss_net_paid)::numeric / 1e6, 2)     AS net_paid_M,
        ROUND(SUM(f.ss_ext_discount_amt)::numeric, 2)    AS total_discount
    FROM fact_store_sales f
    JOIN dim_promotion p ON f.ss_promo_sk = p.promo_sk
    GROUP BY p.promo_sk, p.promo_name, p.purpose, p.cost
),
baseline AS (
    SELECT ROUND(AVG(ss_net_paid)::numeric, 4) AS avg_baseline_txn
    FROM fact_store_sales
    WHERE ss_promo_sk IS NULL
)
SELECT
    ps.promo_name,
    ps.purpose,
    ps.transactions,
    ps.net_paid_M,
    ps.total_discount,
    ps.promo_cost,
    ROUND(
        ps.net_paid_M * 1e6 / NULLIF(ps.promo_cost, 0),
    2) AS revenue_per_promo_dollar
FROM promo_sales ps
CROSS JOIN baseline b
ORDER BY revenue_per_promo_dollar DESC NULLS LAST
LIMIT 15;


-- ==========================================
-- Q6: Monthly sales trend with 3-month moving average (store channel)
-- Spot seasonal patterns and smooth noise.
-- ==========================================

WITH monthly AS (
    SELECT
        d.year,
        d.month,
        ROUND(SUM(f.ss_net_paid)::numeric / 1e6, 2) AS net_paid_M
    FROM fact_store_sales f
    JOIN dim_date d ON f.ss_sold_date_sk = d.date_sk
    WHERE d.year BETWEEN 1998 AND 2002
    GROUP BY d.year, d.month
)
SELECT
    year,
    month,
    net_paid_M,
    ROUND(
        AVG(net_paid_M) OVER (
            ORDER BY year, month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
    2) AS moving_avg_3m
FROM monthly
ORDER BY year, month;


-- ==========================================
-- Q7: Year-over-year revenue growth by channel
-- Uses LAG to compute growth rate without a self-join.
-- ==========================================

WITH yearly AS (
    SELECT
        d.year,
        SUM(s.ss_net_paid)  AS store_paid,
        SUM(w.ws_net_paid)  AS web_paid,
        SUM(c.cs_net_paid)  AS catalog_paid
    FROM dim_date d
    LEFT JOIN fact_store_sales   s ON s.ss_sold_date_sk = d.date_sk
    LEFT JOIN fact_web_sales      w ON w.ws_sold_date_sk = d.date_sk
    LEFT JOIN fact_catalog_sales  c ON c.cs_sold_date_sk = d.date_sk
    WHERE d.year BETWEEN 1998 AND 2002
    GROUP BY d.year
)
SELECT
    year,
    ROUND(store_paid   / 1e6, 2) AS store_paid_M,
    ROUND(web_paid     / 1e6, 2) AS web_paid_M,
    ROUND(catalog_paid / 1e6, 2) AS catalog_paid_M,
    ROUND(
        100.0 * (store_paid - LAG(store_paid) OVER (ORDER BY year))
        / NULLIF(LAG(store_paid) OVER (ORDER BY year), 0),
    2) AS store_yoy_pct,
    ROUND(
        100.0 * (web_paid - LAG(web_paid) OVER (ORDER BY year))
        / NULLIF(LAG(web_paid) OVER (ORDER BY year), 0),
    2) AS web_yoy_pct,
    ROUND(
        100.0 * (catalog_paid - LAG(catalog_paid) OVER (ORDER BY year))
        / NULLIF(LAG(catalog_paid) OVER (ORDER BY year), 0),
    2) AS catalog_yoy_pct
FROM yearly
ORDER BY year;


-- ==========================================
-- Q8: Holiday lift analysis
-- Do customers spend more on holidays vs regular weekdays?
-- ==========================================

SELECT
    CASE
        WHEN d.is_holiday THEN 'Holiday'
        WHEN d.is_weekend THEN 'Weekend'
        ELSE 'Regular weekday'
    END                                               AS day_type,
    COUNT(DISTINCT d.date_sk)                         AS days,
    COUNT(*)                                          AS total_transactions,
    ROUND(SUM(f.ss_net_paid)::numeric / 1e6, 2)      AS total_net_paid_M,
    ROUND(
        SUM(f.ss_net_paid)::numeric
        / NULLIF(COUNT(DISTINCT d.date_sk), 0) / 1e3,
    2)                                                AS avg_daily_revenue_K,
    ROUND(AVG(f.ss_net_paid)::numeric, 2)             AS avg_txn_value
FROM fact_store_sales f
JOIN dim_date d ON f.ss_sold_date_sk = d.date_sk
WHERE d.year BETWEEN 1998 AND 2002
GROUP BY day_type
ORDER BY avg_daily_revenue_K DESC;


-- ==========================================
-- Q9: Top 10 states by net profit (store channel)
-- Geographic revenue concentration.
-- ==========================================

SELECT
    c.state,
    COUNT(DISTINCT f.ss_customer_sk)              AS unique_customers,
    COUNT(*)                                      AS transactions,
    ROUND(SUM(f.ss_net_paid)::numeric   / 1e6, 2) AS net_paid_M,
    ROUND(SUM(f.ss_net_profit)::numeric / 1e6, 2) AS net_profit_M,
    ROUND(
        100.0 * SUM(f.ss_net_profit) / NULLIF(SUM(f.ss_net_paid), 0),
    2)                                             AS profit_margin_pct
FROM fact_store_sales f
JOIN dim_customer c ON f.ss_customer_sk = c.customer_sk
WHERE c.state IS NOT NULL
GROUP BY c.state
ORDER BY net_profit_M DESC
LIMIT 10;


-- ==========================================
-- Q10: Brand profitability — top 20 brands across all channels
-- Union store + web + catalog, then rank by combined profit.
-- ==========================================

WITH channel_sales AS (
    SELECT i.brand, i.category,
           f.ss_net_paid AS net_paid, f.ss_net_profit AS net_profit
    FROM fact_store_sales f JOIN dim_item i ON f.ss_item_sk = i.item_sk

    UNION ALL

    SELECT i.brand, i.category,
           w.ws_net_paid, w.ws_net_profit
    FROM fact_web_sales w JOIN dim_item i ON w.ws_item_sk = i.item_sk

    UNION ALL

    SELECT i.brand, i.category,
           c.cs_net_paid, c.cs_net_profit
    FROM fact_catalog_sales c JOIN dim_item i ON c.cs_item_sk = i.item_sk
)
SELECT
    brand,
    category,
    COUNT(*)                                          AS transactions,
    ROUND(SUM(net_paid)::numeric   / 1e6, 2)         AS total_revenue_M,
    ROUND(SUM(net_profit)::numeric / 1e6, 2)         AS total_profit_M,
    ROUND(
        100.0 * SUM(net_profit) / NULLIF(SUM(net_paid), 0),
    2)                                                AS profit_margin_pct
FROM channel_sales
WHERE brand IS NOT NULL
GROUP BY brand, category
ORDER BY total_profit_M DESC
LIMIT 20;
