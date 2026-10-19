-- 06 risk score and retention
-- Purpose: build a transparent, rules-based churn risk score, check that it actually separates churners from loyal customers, and list active customers to target with retention campaigns.

-- Scoring (points are chosen from the patterns found in script 04):
--   +3  tenure 0-3 months
--   +2  filed a complaint
--   +1  single marital status
--   +1  prefers Mobile Phone category
--   +1  cashback under 130
--   +1  5+ devices registered
--   +1  tenure unknown
-- Maximum = 9. Bands: High >= 5, Medium 3-4, Low <= 2.
--
-- NOTE: satisfaction score and days-since-last-order are deliberately NOT used.
-- In this dataset they do not behave the way intuition suggests (see README).

DROP VIEW IF EXISTS customer_risk;

CREATE VIEW customer_risk AS
SELECT
    c.*,
    (CASE WHEN tenure <= 3 THEN 3 ELSE 0 END
   + CASE WHEN complain = 1 THEN 2 ELSE 0 END
   + CASE WHEN marital_status = 'Single' THEN 1 ELSE 0 END
   + CASE WHEN preferred_order_cat = 'Mobile Phone' THEN 1 ELSE 0 END
   + CASE WHEN cashback_amount < 130 THEN 1 ELSE 0 END
   + CASE WHEN devices_registered >= 5 THEN 1 ELSE 0 END
   + CASE WHEN tenure IS NULL THEN 1 ELSE 0 END) AS risk_score,
    CASE
        WHEN (CASE WHEN tenure <= 3 THEN 3 ELSE 0 END
            + CASE WHEN complain = 1 THEN 2 ELSE 0 END
            + CASE WHEN marital_status = 'Single' THEN 1 ELSE 0 END
            + CASE WHEN preferred_order_cat = 'Mobile Phone' THEN 1 ELSE 0 END
            + CASE WHEN cashback_amount < 130 THEN 1 ELSE 0 END
            + CASE WHEN devices_registered >= 5 THEN 1 ELSE 0 END
            + CASE WHEN tenure IS NULL THEN 1 ELSE 0 END) >= 5 THEN 'High'
        WHEN (CASE WHEN tenure <= 3 THEN 3 ELSE 0 END
            + CASE WHEN complain = 1 THEN 2 ELSE 0 END
            + CASE WHEN marital_status = 'Single' THEN 1 ELSE 0 END
            + CASE WHEN preferred_order_cat = 'Mobile Phone' THEN 1 ELSE 0 END
            + CASE WHEN cashback_amount < 130 THEN 1 ELSE 0 END
            + CASE WHEN devices_registered >= 5 THEN 1 ELSE 0 END
            + CASE WHEN tenure IS NULL THEN 1 ELSE 0 END) >= 3 THEN 'Medium'
        ELSE 'Low'
    END AS risk_band
FROM customers_clean c;

-- 1. Does the score work? Churn rate by risk band
SELECT risk_band,
       COUNT(*) AS customers,
       SUM(churn) AS churned,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(100.0 * SUM(churn) / (SELECT SUM(churn) FROM customers_clean), 2) AS share_of_all_churn_pct
FROM customer_risk
GROUP BY risk_band
ORDER BY CASE risk_band WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;

-- 2. Churn rate by exact score (should rise steadily)
SELECT risk_score,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(churn) / COUNT(*), 2) AS churn_rate_pct
FROM customer_risk
GROUP BY risk_score
ORDER BY risk_score;

-- 3. Retention target list: STILL-ACTIVE customers (churn = 0) in the High band.
--    These are the customers a retention campaign should contact first.
SELECT customer_id, risk_score, tenure, complain, preferred_order_cat,
       marital_status, cashback_amount, devices_registered
FROM customer_risk
WHERE churn = 0 AND risk_band = 'High'
ORDER BY risk_score DESC, tenure ASC
LIMIT 50;

-- 4. How big is the retention target group?
SELECT COUNT(*) AS active_high_risk_customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customer_risk WHERE churn = 0), 2) AS pct_of_active_base
FROM customer_risk
WHERE churn = 0 AND risk_band = 'High';

-- 5. Campaign sizing: historically, each band loses `churned` customers.
--    If a retention programme prevented 20% of that loss, how many customers should be kept? (Change 0.20 to test other scenarios.)
SELECT risk_band,
       COUNT(*) AS customers,
       ROUND(AVG(churn) * COUNT(*) * 0.20, 0) AS customers_saved_at_20pct_success
FROM customer_risk
WHERE risk_band IN ('High', 'Medium')
GROUP BY risk_band;
