"""Run with:  pytest -q"""
import sys
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pipeline"))
import run_pipeline as rp  # noqa: E402


@pytest.fixture
def raw():
    return rp.extract()


def test_real_file_passes_validation(raw):
    rp.validate(raw)


def test_bad_churn_value_is_rejected(raw):
    raw.loc[0, "Churn"] = 2
    with pytest.raises(ValueError, match="Churn must be 0 or 1"):
        rp.validate(raw)


def test_missing_column_is_rejected(raw):
    with pytest.raises(ValueError, match="missing columns"):
        rp.validate(raw.drop(columns=["Complain"]))


def test_out_of_range_satisfaction_is_rejected(raw):
    raw.loc[0, "SatisfactionScore"] = 9
    with pytest.raises(ValueError, match="SatisfactionScore"):
        rp.validate(raw)


def test_too_many_blanks_is_rejected(raw):
    raw.loc[: int(len(raw) * 0.2), "Tenure"] = None
    with pytest.raises(ValueError, match="blank"):
        rp.validate(raw)


def test_transform_renames_and_adds_id(raw):
    out = rp.transform(raw)
    assert "customer_id" in out.columns and out.customer_id.is_unique
    assert {"tenure", "preferred_order_cat", "churn"} <= set(out.columns)
    assert len(out) == len(raw)


def test_pipeline_end_to_end_and_idempotent(tmp_path, monkeypatch):
    db = tmp_path / "test.db"
    monkeypatch.setattr(rp, "DB_PATH", db)
    clean = rp.transform(rp.extract())
    for _ in range(2):  # run twice: row count must not double
        rp.load(clean, db)
        rp.build_views(db)
        result = rp.reconcile(db, expected_rows=len(clean))
    assert result == {"customers": 3941, "churned": 674, "churn_rate_pct": 17.1, "active_high_risk": 329}
