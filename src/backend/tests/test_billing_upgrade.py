"""Unit tests for Story 1.1 -- Self-Serve Mid-Cycle Upgrade: Standard -> Premium.

Covers REQ-F-01..11, REQ-NF-01..05 (spec/plans/requirements.md) via stories.md
Story 1.1 AC-1..AC-7 (spec/plans/stories.md).
"""

import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient

import main


@pytest.fixture(autouse=True)
def reset_state():
    """Each test gets a fresh Standard subscriber and a fresh fail* subscriber."""
    main.users["standard@example.com"] = {
        "id": 100,
        "name": "Standard User",
        "email": "standard@example.com",
        "password": "password",
        "plan": "Standard",
        "price": "$20/month",
        "renew_at": (datetime.today() + timedelta(days=15)).strftime("%b %d, %Y"),
    }
    main.billing_data["standard@example.com"] = {
        "plan_name": "Standard",
        "price": "$20/month",
        "renew_at": main.users["standard@example.com"]["renew_at"],
        "usages": [
            {"id": "chat-credits", "label": "Chat credits", "used": 100, "total": 2000, "help": "h"},
            {"id": "chatbots", "label": "Chatbots", "used": 1, "total": 3, "help": "h"},
            {"id": "documents-pages", "label": "Documents pages", "used": 15, "total": 1000, "help": "h"},
        ],
        "on_demand_usage": {
            "title": "On-demand usage",
            "remaining_balance": "$18.00",
            "your_usage": "$0.00",
            "help": "h",
            "notice": "On-demand credit is not available in standard plan for usage beyond your included quota.",
        },
    }

    main.users["fail@example.com"] = {
        "id": 101,
        "name": "Fail User",
        "email": "fail@example.com",
        "password": "password",
        "plan": "Standard",
        "price": "$20/month",
        "renew_at": (datetime.today() + timedelta(days=15)).strftime("%b %d, %Y"),
    }
    main.billing_data["fail@example.com"] = {
        "plan_name": "Standard",
        "price": "$20/month",
        "renew_at": main.users["fail@example.com"]["renew_at"],
        "usages": [
            {"id": "chat-credits", "label": "Chat credits", "used": 100, "total": 2000, "help": "h"},
        ],
        "on_demand_usage": {
            "title": "On-demand usage",
            "remaining_balance": "$18.00",
            "your_usage": "$0.00",
            "help": "h",
            "notice": "On-demand credit is not available in standard plan for usage beyond your included quota.",
        },
    }

    main.users["premium@example.com"] = {
        "id": 102,
        "name": "Premium User",
        "email": "premium@example.com",
        "password": "password",
        "plan": "Premium",
        "price": "$40/month",
        "renew_at": (datetime.today() + timedelta(days=15)).strftime("%b %d, %Y"),
    }
    main.billing_data["premium@example.com"] = {
        "plan_name": "Premium",
        "price": "$40/month",
        "renew_at": main.users["premium@example.com"]["renew_at"],
        "usages": [{"id": "chat-credits", "label": "Chat credits", "used": 0, "total": 10000, "help": "h"}],
        "on_demand_usage": {
            "title": "On-demand usage",
            "remaining_balance": "$0.00",
            "your_usage": "$0.00",
            "help": "h",
            "notice": main.PREMIUM_ON_DEMAND_NOTICE,
        },
    }

    yield

    for email in ("standard@example.com", "fail@example.com", "premium@example.com"):
        main.users.pop(email, None)
        main.billing_data.pop(email, None)


@pytest.fixture
def client():
    return TestClient(main.app)


# --- AC-1: charge_card determinism (REQ-NF-01, ARCH-02) ------------------------


def test_charge_card_success_for_non_fail_email():
    assert main.charge_card("standard@example.com", 10.0) == {"status": "success"}


def test_charge_card_declines_fail_prefixed_email():
    result = main.charge_card("fail@example.com", 10.0)
    assert result["status"] == "card_declined"
    assert result["message"] == "Your card was declined."


def test_charge_card_deterministic_repeated_calls():
    first = main.charge_card("standard@example.com", 10.0)
    second = main.charge_card("standard@example.com", 10.0)
    assert first == second


# --- AC-2: preview endpoint + server-side proration (REQ-F-03, REQ-F-04, ARCH-01) --


def test_upgrade_preview_returns_prorated_charge(client):
    resp = client.get("/api/billing/upgrade-preview", params={"email": "standard@example.com"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["current_plan"] == "Standard"
    assert body["new_plan"] == "Premium"
    # renew_at carries the fixture's time-of-day, and (renew_at_date - datetime.today()).days
    # (epic-brief.md's own formula) truncates the instant ANY wall-clock time elapses between
    # fixture setup and the request -- so 15 calendar days out deterministically reads as 14 or
    # 15 depending on exactly how many microseconds passed. Both are correct for this formula.
    assert body["days_remaining"] in (14, 15)
    expected_charge = round((40.0 - 20.0) / 30 * body["days_remaining"], 2)
    assert body["prorated_charge"] == expected_charge
    assert body["next_renewal_price"] == 40.0


def test_proration_formula_matches_epic_example():
    # ~15 days remaining -> (40-20)/30 * days = ~$10, per epic-brief.md's worked example.
    # See the truncation note above for why days_remaining lands on 14 or 15.
    days_remaining, prorated_charge = main._calculate_proration(
        (datetime.today() + timedelta(days=15)).strftime("%b %d, %Y")
    )
    assert days_remaining in (14, 15)
    assert prorated_charge == round((40.0 - 20.0) / 30 * days_remaining, 2)


# --- AC-4: happy-path upgrade (REQ-F-06, REQ-F-07, REQ-NF-01, REQ-NF-02) ----------


_VALID_CHARGES = (round((40.0 - 20.0) / 30 * 14, 2), round((40.0 - 20.0) / 30 * 15, 2))


def test_successful_upgrade_response_body(client):
    resp = client.post("/api/billing/upgrade", json={"email": "standard@example.com"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "success"
    assert body["plan"] == "Premium"
    # See the days_remaining truncation note above -- 14 or 15 days both yield a correct charge.
    assert body["charge"] in _VALID_CHARGES


def test_successful_upgrade_flips_users_and_billing_plan(client):
    client.post("/api/billing/upgrade", json={"email": "standard@example.com"})
    assert main.users["standard@example.com"]["plan"] == "Premium"
    assert main.users["standard@example.com"]["price"] == "$40/month"
    data = main.billing_data["standard@example.com"]
    assert data["plan_name"] == "Premium"
    assert data["price"] == "$40/month"
    assert data["on_demand_usage"]["notice"] == main.PREMIUM_ON_DEMAND_NOTICE


def test_successful_upgrade_sets_premium_quota_totals(client):
    client.post("/api/billing/upgrade", json={"email": "standard@example.com"})
    totals = {u["id"]: u["total"] for u in main.billing_data["standard@example.com"]["usages"]}
    assert totals["chat-credits"] == 10000
    assert totals["chatbots"] == 10
    assert totals["documents-pages"] == 5000


def test_successful_upgrade_preserves_renew_at(client):
    before = main.billing_data["standard@example.com"]["renew_at"]
    client.post("/api/billing/upgrade", json={"email": "standard@example.com"})
    after = main.billing_data["standard@example.com"]["renew_at"]
    assert before == after


# --- AC-5: failure path leaves state untouched (REQ-F-08, REQ-F-09, ARCH-03) ------


def test_declined_upgrade_returns_402_with_message(client):
    resp = client.post("/api/billing/upgrade", json={"email": "fail@example.com"})
    assert resp.status_code == 402
    body = resp.json()
    assert body["detail"] == "card_declined"
    assert body["message"] == "Your card was declined."


def test_declined_upgrade_mutates_nothing(client):
    before_user = dict(main.users["fail@example.com"])
    before_billing = dict(main.billing_data["fail@example.com"])
    client.post("/api/billing/upgrade", json={"email": "fail@example.com"})
    assert main.users["fail@example.com"] == before_user
    assert main.billing_data["fail@example.com"] == before_billing


# --- AC-6: already-Premium guard on both endpoints (REQ-F-10) ---------------------


def test_preview_already_premium_returns_409(client):
    resp = client.get("/api/billing/upgrade-preview", params={"email": "premium@example.com"})
    assert resp.status_code == 409
    assert resp.json()["detail"] == "already_premium"


def test_upgrade_already_premium_returns_409_and_no_mutation(client):
    before = dict(main.billing_data["premium@example.com"])
    resp = client.post("/api/billing/upgrade", json={"email": "premium@example.com"})
    assert resp.status_code == 409
    assert resp.json()["detail"] == "already_premium"
    assert main.billing_data["premium@example.com"] == before


# --- Auth boundary (REQ-F-11 -- no change to auth semantics on the new endpoints) --


def test_preview_requires_known_email(client):
    resp = client.get("/api/billing/upgrade-preview", params={"email": "nobody@example.com"})
    assert resp.status_code == 401


def test_upgrade_requires_known_email(client):
    resp = client.post("/api/billing/upgrade", json={"email": "nobody@example.com"})
    assert resp.status_code == 401


# --- AC-1: existing /api/billing still exposes plan_name for the dynamic badge ----


def test_billing_endpoint_exposes_plan_name(client):
    resp = client.get("/api/billing", params={"email": "standard@example.com"})
    assert resp.status_code == 200
    assert resp.json()["plan_name"] == "Standard"
