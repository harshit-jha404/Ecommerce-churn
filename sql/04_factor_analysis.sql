-- 04 factor analysis
-- Purpose: churn rate by each individual factor.

-- A. COMPLAINTS 
SELECT
    CASE WHEN complain = 1 THEN 'Complained' ELSE 'No complaint' END AS grp,
    COUNT(*) AS customers,
    SUM(churn) AS churned,
    ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(100.0 * SUM(churn) / COUNT(*)
          - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY complain
ORDER BY churn_rate_pct DESC;

-- B. TENURE
SELECT tenure_bucket AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY tenure_bucket
ORDER BY tenure_bucket;

-- C. SATISFACTION SCORE
SELECT satisfaction_score AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY satisfaction_score
ORDER BY satisfaction_score;

-- D. DAYS SINCE LAST ORDER
SELECT recency_bucket AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY recency_bucket
ORDER BY recency_bucket;

-- E. CASHBACK 
SELECT cashback_bucket AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY cashback_bucket
ORDER BY cashback_bucket;

-- F. PREFERRED ORDER CATEGORY
SELECT preferred_order_cat AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY preferred_order_cat
ORDER BY churn_rate_pct DESC;

-- G. MARITAL STATUS
SELECT marital_status AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY marital_status
ORDER BY churn_rate_pct DESC;

-- H. NUMBER OF DEVICES REGISTERED
SELECT devices_registered AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY devices_registered
ORDER BY devices_registered;

-- I. NUMBER OF SAVED ADDRESSES
SELECT address_bucket AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY address_bucket
ORDER BY address_bucket;

-- J. WAREHOUSE TO HOME DISTANCE
SELECT distance_bucket AS grp,
       COUNT(*) AS customers, SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / COUNT(*)
             - (SELECT 100.0 * SUM(churn) / COUNT(*) FROM customers_clean), 2) AS vs_overall_pts
FROM customers_clean
GROUP BY distance_bucket
ORDER BY distance_bucket;

-- K. WHICH FACTOR MATTERS MOST?
-- Churn-rate spread (highest group minus lowest group) per factor.
-- A bigger spread = a stronger signal. Only groups with 100+ customers count, so tiny groups don't inflate the spread.
WITH factor_rates AS (
    SELECT 'Complaint' AS factor, CAST(complain AS CHAR(30)) AS grp, COUNT(*) AS n, 100.0 * SUM(churn) / COUNT(*) AS rate FROM customers_clean GROUP BY complain
    UNION ALL SELECT 'Tenure', tenure_bucket, COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY tenure_bucket
    UNION ALL SELECT 'Satisfaction', CAST(satisfaction_score AS CHAR(30)), COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY satisfaction_score
    UNION ALL SELECT 'Recency', recency_bucket, COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY recency_bucket
    UNION ALL SELECT 'Cashback', cashback_bucket, COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY cashback_bucket
    UNION ALL SELECT 'Order category', preferred_order_cat, COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY preferred_order_cat
    UNION ALL SELECT 'Marital status', marital_status, COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY marital_status
    UNION ALL SELECT 'Devices', CAST(devices_registered AS CHAR(30)), COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY devices_registered
    UNION ALL SELECT 'Addresses', address_bucket, COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY address_bucket
    UNION ALL SELECT 'Distance', distance_bucket, COUNT(*), 100.0 * SUM(churn) / COUNT(*) FROM customers_clean GROUP BY distance_bucket
)
SELECT factor,
       ROUND(MAX(rate), 1) AS highest_group_churn_pct,
       ROUND(MIN(rate), 1) AS lowest_group_churn_pct,
       ROUND(MAX(rate) - MIN(rate), 1) AS spread_pts
FROM factor_rates
WHERE n >= 100
GROUP BY factor
ORDER BY spread_pts DESC;
