"""
run_pipeline.py  -  one command rebuilds the whole project database.

    python pipeline/run_pipeline.py

Steps:  EXTRACT -> VALIDATE -> TRANSFORM -> LOAD -> BUILD VIEWS -> RECONCILE
Safe to re-run: the table is replaced each time, so rows are never duplicated.
"""
import logging
import sqlite3
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data" / "data_ecommerce_customer_churn.csv"
DB_PATH = ROOT / "churn.db"
SQL_DIR = ROOT / "sql"

# Column names in the raw CSV -> clean snake_case names used by the SQL scripts
COLUMN_MAP = {
    "Tenure": "tenure",
    "WarehouseToHome": "warehouse_to_home",
    "NumberOfDeviceRegistered": "devices_registered",
    "PreferedOrderCat": "preferred_order_cat",
    "SatisfactionScore": "satisfaction_score",
    "MaritalStatus": "marital_status",
    "NumberOfAddress": "num_addresses",
    "Complain": "complain",
    "DaySinceLastOrder": "days_since_last_order",
    "CashbackAmount": "cashback_amount",
    "Churn": "churn",
}
NULLABLE = ["tenure", "warehouse_to_home", "days_since_last_order"]  # known to have blanks
MAX_NULL_SHARE = 0.10  # fail if more than 10% of any nullable column is blank

log = logging.getLogger("pipeline")


def extract(path: Path = CSV_PATH) -> pd.DataFrame:
    log.info("EXTRACT  reading %s", path.name)
    df = pd.read_csv(path)
    log.info("EXTRACT  %d rows, %d columns", *df.shape)
    return df


def validate(df: pd.DataFrame) -> None:
    """Raise ValueError with every problem found. Nothing is silently fixed here."""
    problems = []
    missing_cols = set(COLUMN_MAP) - set(df.columns)
    if missing_cols:
        problems.append(f"missing columns: {sorted(missing_cols)}")
    else:
        if len(df) == 0:
            problems.append("file has no rows")
        if not df["Churn"].isin([0, 1]).all():
            problems.append("Churn must be 0 or 1")
        if not df["Complain"].isin([0, 1]).all():
            problems.append("Complain must be 0 or 1")
        if not df["SatisfactionScore"].between(1, 5).all():
            problems.append("SatisfactionScore must be between 1 and 5")
        if (df["CashbackAmount"] < 0).any():
            problems.append("CashbackAmount must not be negative")
        if (df["Tenure"].dropna() < 0).any():
            problems.append("Tenure must not be negative")
        for raw in ("Tenure", "WarehouseToHome", "DaySinceLastOrder"):
            share = df[raw].isna().mean()
            if share > MAX_NULL_SHARE:
                problems.append(f"{raw} is {share:.1%} blank (limit {MAX_NULL_SHARE:.0%})")
    if problems:
        for p in problems:
            log.error("VALIDATE %s", p)
        raise ValueError("Validation failed: " + "; ".join(problems))
    log.info("VALIDATE all checks passed")


def transform(df: pd.DataFrame) -> pd.DataFrame:
    df = df.rename(columns=COLUMN_MAP).copy()
    df["preferred_order_cat"] = df["preferred_order_cat"].str.strip()
    for col in NULLABLE + ["devices_registered", "num_addresses", "satisfaction_score"]:
        df[col] = df[col].astype("Int64")
    df.insert(0, "customer_id", range(1, len(df) + 1))
    dups = df.drop(columns="customer_id").duplicated().sum()
    log.info("TRANSFORM renamed columns, added customer_id; %d exact duplicate rows flagged (kept)", dups)
    return df


def load(df: pd.DataFrame, db_path: Path = DB_PATH) -> None:
    with sqlite3.connect(db_path) as con:
        df.to_sql("customers_raw", con, if_exists="replace", index=False)
    log.info("LOAD     %d rows written to customers_raw in %s", len(df), db_path.name)


def build_views(db_path: Path = DB_PATH) -> None:
    """Run the cleaning view (02) and risk-score view (06) from the sql/ folder."""
    with sqlite3.connect(db_path) as con:
        for script in ("02_data_cleaning.sql", "06_risk_score_and_retention.sql"):
            con.executescript((SQL_DIR / script).read_text())
            log.info("VIEWS    ran %s", script)


def reconcile(db_path: Path = DB_PATH, expected_rows: int = None) -> dict:
    """Cross-check the database against the raw file so silent errors get caught."""
    with sqlite3.connect(db_path) as con:
        total, churned = con.execute(
            "SELECT COUNT(*), SUM(churn) FROM customers_clean").fetchone()
        active_high = con.execute(
            "SELECT COUNT(*) FROM customer_risk WHERE churn = 0 AND risk_band = 'High'").fetchone()[0]
    if expected_rows is not None and total != expected_rows:
        raise RuntimeError(f"Row count mismatch: file {expected_rows}, database {total}")
    result = {"customers": total, "churned": int(churned),
              "churn_rate_pct": round(100 * churned / total, 2), "active_high_risk": active_high}
    log.info("RECONCILE %s", result)
    return result


def main() -> dict:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)-7s %(message)s",
                        datefmt="%H:%M:%S")
    raw = extract()
    validate(raw)
    clean = transform(raw)
    load(clean)
    build_views()
    result = reconcile(expected_rows=len(raw))
    log.info("DONE     pipeline finished OK")
    return result


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # fail loudly with a non-zero exit code
        log.error("PIPELINE FAILED: %s", exc)
        sys.exit(1)
