"""Smoke test bootstrapped by AIRE so the CI pipeline's unit+coverage gate has a real,
existing test suite to run against before any story is implemented (see
common/eval-framework.md Section 2.3 — a check with no config/tests is "not set up
yet", not N/A). Extended per-story by dev-implement; never deleted.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import main  # noqa: E402


def test_app_exists():
    assert main.app is not None
    assert main.app.title == "Billing & Tasks POC"


def test_seed_data_shapes():
    assert "tpg@example.com" in main.users
    assert main.users["tpg@example.com"]["plan"] == "Standard"
    assert "tpg@example.com" in main.billing_data
    assert main.billing_data["tpg@example.com"]["plan_name"] == "Standard"
