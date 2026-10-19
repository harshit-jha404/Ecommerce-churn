-- 03 churn overview 
-- Purpose: establish the baseline churn rate every segment is compared to.

-- 1. Overall churn rate
SELECT
    COUNT(*) AS total_customers,
    SUM(churn) AS churned_customers,
    COUNT(*) - SUM(churn) AS retained_customers,
    ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct
FROM customers_clean;

-- 2. Churned vs retained: average profile
SELECT
    CASE WHEN churn = 1 THEN 'Churned' ELSE 'Retained' END AS status,
    COUNT(*) AS customers,
    ROUND(AVG(tenure), 1) AS avg_tenure_months,
    ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction,
    ROUND(AVG(days_since_last_order), 1) AS avg_days_since_last_order,
    ROUND(AVG(cashback_amount), 2) AS avg_cashback,
    ROUND(AVG(num_addresses), 1) AS avg_addresses,
    ROUND(AVG(devices_registered), 1) AS avg_devices,
    ROUND(100.0 * SUM(complain) / COUNT(*), 1) AS pct_with_complaint
FROM customers_clean
GROUP BY churn
ORDER BY churn DESC;
