# How the pipeline and model work (plain-language guide)

Read this before an interview. Every claim below can be checked by running the code.

## 1. The pipeline (`pipeline/run_pipeline.py`)
Think of it as the SQL project on autopilot. One command re-does everything:

| Stage | What it does | Why it matters |
|---|---|---|
| Extract | Reads the CSV into a pandas table | Starting point |
| Validate | Checks the file before using it: required columns exist, `Churn` is 0/1, satisfaction is 1-5, no negative cashback, blanks under 10% | Bad data is stopped early instead of silently producing wrong dashboards |
| Transform | Renames columns to snake_case, fixes data types, adds `customer_id`, counts duplicate rows | Makes the data match what the SQL scripts expect |
| Load | Writes the data into the `customers_raw` table, **replacing** the old one | Re-running never creates duplicate rows (this is called *idempotent*) |
| Build views | Runs `sql/02_data_cleaning.sql` and `sql/06_risk_score_and_retention.sql` | The same SQL logic is reused, not rewritten |
| Reconcile | Confirms the database holds 3,941 customers, 674 churned, 329 active high-risk | Catches silent loading errors |

Every step writes a log line, and any failure stops the run with an error code (so a scheduler could detect it).

**Tests (`tests/test_pipeline.py`, run with `pytest -q`):** 7 automated checks, including "bad data is rejected" and "running the pipeline twice gives the same result".

## 2. The model (`pipeline/model.py`)
**Goal:** predict, for each customer, the probability of churning.

1. **Prepare:** blank numbers are filled with the median (plus a flag saying "this was blank"), text columns are turned into 0/1 columns, numbers are rescaled.
2. **Split:** 80% of customers train the model, 20% are held back as a **test set** the model never sees. This is the honest way to measure performance.
3. **Remove duplicates before splitting.** The file has identical rows. If one copy lands in training and another in testing, the model is effectively given the answers, which inflates scores.
4. **Handle imbalance:** only ~17% of customers churn, so a model that always predicts "stays" would be 83% accurate and useless. We therefore use class weights and report **ROC-AUC, precision and recall** instead of accuracy.
5. **Compare three models:** logistic regression (simple, explainable), random forest and gradient boosting (more flexible).
6. **Benchmark against your SQL score:** the rules-based risk score is evaluated on the same test customers.

**Metric glossary**
- **ROC-AUC:** how well the model ranks churners above non-churners. 0.5 is random, 1.0 is perfect.
- **Precision:** of customers flagged as churners, the share who really churned.
- **Recall:** of customers who really churned, the share we caught.

## 3. Results (test set, 654 customers)
| Model | ROC-AUC | Precision | Recall |
|---|---|---|---|
| Random forest | 0.952 | 0.70 | 0.81 |
| Gradient boosting | 0.948 | 0.73 | 0.66 |
| Logistic regression | 0.924 | 0.43 | 0.92 |
| SQL risk score (rules) | 0.890 | n/a | n/a |

- The best model is the random forest. It ranks customers better than the hand-built SQL score (0.95 vs 0.89), but the SQL score is surprisingly competitive for a few lines of CASE WHEN.
- **Most important inputs:** tenure by a wide margin, then complaints. This matches the SQL findings.
- The scores come from a small dataset (about 3,300 unique customers). Treat them as indicative, not as production performance.

## 4. Outputs (`outputs/`)
- `model_comparison.csv`: the table above.
- `feature_importance.csv`: how much each input matters.
- `churn_scores.csv`: churn probability for every active customer, best targets first. Load this into Power BI to add a "model-based" retention list next to the rules-based one.

## 5. Questions you may be asked, and honest answers
- **Why did you validate before loading?** So bad data fails loudly instead of quietly breaking the dashboard.
- **Why not use accuracy?** 83% of customers don't churn, so accuracy hides failures. ROC-AUC, precision and recall show how well churners are found.
- **Why remove duplicates?** To stop identical rows appearing in both train and test, which would inflate the metrics.
- **Is 0.95 AUC realistic?** For a clean, small public dataset, yes, but it would likely be lower on live data. I would validate on a later time period if dates were available.
- **Why keep the SQL risk score?** It is transparent and easy for a business team to use, and it scored close to the model. A simple rule can be the right answer.
- **What would you do next?** Schedule the pipeline (Airflow or cron), add monitoring, and retrain when new data arrives.
- **What did you write yourself?** Be honest about what you did and what you used help for, and make sure you can explain every step above.
