-- 05 customer segmentation
-- Purpose: combine factors to find high-risk customer groups.

-- 1. Business segments 
SELECT
    segment,
    COUNT(*) AS customers,
    SUM(churn) AS churned,
    ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(100.0 * SUM(churn) / (SELECT SUM(churn) FROM customers_clean), 2) AS share_of_all_churn_pct
FROM (
    SELECT *,
        CASE
            WHEN tenure <= 3 AND complain = 1 THEN 'A. New + complained'
            WHEN tenure <= 3 AND preferred_order_cat = 'Mobile Phone' THEN 'B. New + mobile phone buyer'
            WHEN tenure <= 3 THEN 'C. New (other)'
            WHEN complain = 1 AND marital_status = 'Single' THEN 'D. Single + complained'
            WHEN complain = 1 THEN 'E. Established + complained'
            WHEN tenure IS NULL THEN 'F. Tenure unknown'
            ELSE 'G. Established, no complaint'
        END AS segment
    FROM customers_clean
) s
GROUP BY segment
ORDER BY segment;

-- 2. Tenure x Complaint matrix
SELECT tenure_bucket,
       CASE WHEN complain = 1 THEN 'Complained' ELSE 'No complaint' END AS complaint_status,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct
FROM customers_clean
GROUP BY tenure_bucket, complain
ORDER BY tenure_bucket, complain DESC;

-- 3. Order category x Marital status (min 30 customers per cell)
SELECT preferred_order_cat, marital_status,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct
FROM customers_clean
GROUP BY preferred_order_cat, marital_status
HAVING COUNT(*) >= 30
ORDER BY churn_rate_pct DESC;

-- 4. Top 10 riskiest two-factor combinations (min 50 customers)
--    Ranks tenure bucket x order category x complaint with a window function.
SELECT * FROM (
    SELECT tenure_bucket, preferred_order_cat,
           CASE WHEN complain = 1 THEN 'Complained' ELSE 'No complaint' END AS complaint_status,
           COUNT(*) AS customers,
           ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
           RANK() OVER (ORDER BY 100.0 * SUM(churn) / COUNT(*) DESC) AS risk_rank
    FROM customers_clean
    GROUP BY tenure_bucket, preferred_order_cat, complain
    HAVING COUNT(*) >= 50
) ranked
WHERE risk_rank <= 10
ORDER BY risk_rank;

-- 5. Safest segments (useful to describe "loyal" customers)
SELECT * FROM (
    SELECT tenure_bucket, preferred_order_cat, marital_status,
           COUNT(*) AS customers,
           ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
           RANK() OVER (ORDER BY 100.0 * SUM(churn) / COUNT(*) ASC) AS loyalty_rank
    FROM customers_clean
    GROUP BY tenure_bucket, preferred_order_cat, marital_status
    HAVING COUNT(*) >= 50
) ranked
WHERE loyalty_rank <= 10
ORDER BY loyalty_rank;
