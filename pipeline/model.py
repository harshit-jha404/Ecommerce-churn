"""
model.py  -  trains churn models, compares them with the SQL risk score,
and scores every active customer.

    python pipeline/model.py      (run run_pipeline.py first)

Outputs go to outputs/:
    model_comparison.csv   test-set metrics for each model + the SQL score
    feature_importance.csv which inputs the best model relies on
    churn_scores.csv       churn probability for every ACTIVE customer (import into Power BI)
"""
import logging
import sqlite3
from pathlib import Path

import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import precision_score, recall_score, roc_auc_score, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "churn.db"
OUT = ROOT / "outputs"
SEED = 42
log = logging.getLogger("model")

NUMERIC = ["tenure", "warehouse_to_home", "devices_registered", "satisfaction_score",
           "num_addresses", "complain", "days_since_last_order", "cashback_amount"]
CATEGORICAL = ["preferred_order_cat", "marital_status"]
FEATURES = NUMERIC + CATEGORICAL


def load_data(db_path: Path = DB_PATH) -> pd.DataFrame:
    with sqlite3.connect(db_path) as con:
        return pd.read_sql("SELECT * FROM customer_risk", con)


def make_preprocessor() -> ColumnTransformer:
    # Blank numbers -> median (and a flag column says they were blank, since
    # missing tenure itself carried signal); text columns -> one-hot columns.
    num = Pipeline([("impute", SimpleImputer(strategy="median", add_indicator=True)),
                    ("scale", StandardScaler())])
    cat = OneHotEncoder(handle_unknown="ignore")
    return ColumnTransformer([("num", num, NUMERIC), ("cat", cat, CATEGORICAL)])


def make_models() -> dict:
    # class_weight="balanced" because only ~17% of customers churn
    return {
        "Logistic regression": LogisticRegression(max_iter=1000, class_weight="balanced"),
        "Random forest": RandomForestClassifier(n_estimators=300, min_samples_leaf=3,
                                                class_weight="balanced", random_state=SEED, n_jobs=-1),
        "Gradient boosting": GradientBoostingClassifier(random_state=SEED),
    }


def metrics(y_true, prob, threshold=0.5) -> dict:
    pred = (prob >= threshold).astype(int)
    return {"roc_auc": round(roc_auc_score(y_true, prob), 3),
            "precision": round(precision_score(y_true, pred, zero_division=0), 3),
            "recall": round(recall_score(y_true, pred), 3),
            "f1": round(f1_score(y_true, pred), 3)}


def run(db_path: Path = DB_PATH) -> pd.DataFrame:
    OUT.mkdir(exist_ok=True)
    data = load_data(db_path)

    # Remove exact duplicate rows for EVALUATION only: identical rows landing in both
    # train and test would let a model "memorise" answers and inflate the scores.
    model_df = data.drop_duplicates(subset=FEATURES + ["churn"]).reset_index(drop=True)
    log.info("evaluation set: %d rows (%d exact duplicates removed)", len(model_df), len(data) - len(model_df))

    X, y = model_df[FEATURES], model_df["churn"]
    X_tr, X_te, y_tr, y_te, idx_tr, idx_te = train_test_split(
        X, y, model_df.index, test_size=0.2, stratify=y, random_state=SEED)

    rows, fitted = [], {}
    for name, clf in make_models().items():
        pipe = Pipeline([("prep", make_preprocessor()), ("model", clf)]).fit(X_tr, y_tr)
        fitted[name] = pipe
        rows.append({"model": name, **metrics(y_te, pipe.predict_proba(X_te)[:, 1])})

    # Benchmark: how well does the rules-based SQL risk score rank the same test customers?
    sql_score = model_df.loc[idx_te, "risk_score"]
    rows.append({"model": "SQL risk score (rules)", "roc_auc": round(roc_auc_score(y_te, sql_score), 3),
                 "precision": None, "recall": None, "f1": None})
    comparison = pd.DataFrame(rows).sort_values("roc_auc", ascending=False)
    comparison.to_csv(OUT / "model_comparison.csv", index=False)
    log.info("\n%s", comparison.to_string(index=False))

    # Best model (by ROC-AUC) -> feature importance on the held-out test set
    best_name = comparison[comparison.model.isin(fitted)].iloc[0]["model"]
    best = fitted[best_name]
    imp = permutation_importance(best, X_te, y_te, scoring="roc_auc", n_repeats=10, random_state=SEED)
    importance = (pd.DataFrame({"feature": FEATURES, "importance": imp.importances_mean.round(4)})
                  .sort_values("importance", ascending=False))
    importance.to_csv(OUT / "feature_importance.csv", index=False)
    log.info("best model: %s\n%s", best_name, importance.to_string(index=False))

    # Score every ACTIVE customer (churn = 0) with the best model
    active = data[data.churn == 0].copy()
    active["churn_probability"] = best.predict_proba(active[FEATURES])[:, 1].round(4)
    active["model_band"] = pd.cut(active["churn_probability"], [-0.01, 0.3, 0.6, 1.0],
                                  labels=["Low", "Medium", "High"])
    cols = ["customer_id", "churn_probability", "model_band", "risk_score", "risk_band",
            "tenure", "complain", "preferred_order_cat", "marital_status", "cashback_amount"]
    active.sort_values("churn_probability", ascending=False)[cols].to_csv(
        OUT / "churn_scores.csv", index=False)
    log.info("scored %d active customers -> outputs/churn_scores.csv", len(active))
    return comparison


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)-7s %(message)s", datefmt="%H:%M:%S")
    run()
