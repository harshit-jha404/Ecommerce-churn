-- 02 data cleaning
-- Purpose: profile data quality, then build a clean analysis view.
-- 1. Row count
SELECT COUNT(*) AS total_rows FROM customers_raw;

-- 2. Missing values per column
SELECT
    SUM(CASE WHEN tenure                IS NULL THEN 1 ELSE 0 END) AS missing_tenure,
    SUM(CASE WHEN warehouse_to_home     IS NULL THEN 1 ELSE 0 END) AS missing_warehouse_to_home,
    SUM(CASE WHEN days_since_last_order IS NULL THEN 1 ELSE 0 END) AS missing_days_since_last_order
FROM customers_raw;

-- 3. Inconsistent category labels 
SELECT preferred_order_cat, COUNT(*) AS customers
FROM customers_raw
GROUP BY preferred_order_cat
ORDER BY customers DESC;

-- 4. Exact duplicate rows
--    The dataset has no customer ID, so identical rows may be different people
--    with similar profiles. We FLAG them but do not delete them.
SELECT COUNT(*) AS duplicate_row_groups, SUM(cnt - 1) AS extra_duplicate_rows
FROM (
    SELECT COUNT(*) AS cnt
    FROM customers_raw
    GROUP BY tenure, warehouse_to_home, devices_registered, preferred_order_cat,
             satisfaction_score, marital_status, num_addresses, complain,
             days_since_last_order, cashback_amount, churn
    HAVING COUNT(*) > 1
) d;

-- 5. Range / outlier checks
SELECT MIN(tenure) AS min_tenure, MAX(tenure) AS max_tenure,
       MIN(warehouse_to_home) AS min_wh, MAX(warehouse_to_home) AS max_wh,
       MIN(days_since_last_order) AS min_dslo, MAX(days_since_last_order) AS max_dslo,
       MIN(cashback_amount) AS min_cashback, MAX(cashback_amount) AS max_cashback
FROM customers_raw;

-- 6. Does missingness relate to churn? 
SELECT CASE WHEN tenure IS NULL THEN 'Tenure missing' ELSE 'Tenure present' END AS tenure_status,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct
FROM customers_raw
GROUP BY CASE WHEN tenure IS NULL THEN 'Tenure missing' ELSE 'Tenure present' END;

DROP VIEW IF EXISTS customers_clean;

CREATE VIEW customers_clean AS
SELECT
    customer_id,
    tenure,
    warehouse_to_home,
    devices_registered,
    CASE WHEN preferred_order_cat = 'Mobile' THEN 'Mobile Phone'
         ELSE preferred_order_cat END AS preferred_order_cat,
    satisfaction_score,
    marital_status,
    num_addresses,
    complain,
    days_since_last_order,
    cashback_amount,
    churn,

    CASE WHEN tenure IS NULL THEN 'Unknown'
         WHEN tenure <= 3   THEN '1. 0-3 months'
         WHEN tenure <= 6   THEN '2. 4-6 months'
         WHEN tenure <= 12  THEN '3. 7-12 months'
         WHEN tenure <= 24  THEN '4. 13-24 months'
         ELSE                    '5. 24+ months' END       AS tenure_bucket,

    CASE WHEN days_since_last_order IS NULL THEN 'Unknown'
         WHEN days_since_last_order <= 3  THEN '1. 0-3 days'
         WHEN days_since_last_order <= 7  THEN '2. 4-7 days'
         WHEN days_since_last_order <= 14 THEN '3. 8-14 days'
         ELSE                                  '4. 15+ days' END AS recency_bucket,

    CASE WHEN cashback_amount < 130 THEN '1. Under 130'
         WHEN cashback_amount < 160 THEN '2. 130-159'
         WHEN cashback_amount < 200 THEN '3. 160-199'
         ELSE                            '4. 200+' END     AS cashback_bucket,

    CASE WHEN num_addresses <= 2 THEN '1. 1-2'
         WHEN num_addresses <= 4 THEN '2. 3-4'
         WHEN num_addresses <= 6 THEN '3. 5-6'
         ELSE                         '4. 7+' END           AS address_bucket,

    CASE WHEN warehouse_to_home IS NULL THEN 'Unknown'
         WHEN warehouse_to_home <= 10 THEN '1. 0-10'
         WHEN warehouse_to_home <= 20 THEN '2. 11-20'
         WHEN warehouse_to_home <= 30 THEN '3. 21-30'
         ELSE                              '4. 30+' END     AS distance_bucket
FROM customers_raw;

-- Quick check
SELECT * FROM customers_clean LIMIT 5;
