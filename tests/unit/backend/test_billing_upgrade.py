from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

import main
from main import app, billing_data, charge_card, users

client = TestClient(app)

_counter = {"n": 0}


def _new_email(prefix="user"):
    _counter["n"] += 1
    return f"{prefix}{_counter['n']}@example.com"


def _register(email, password="password"):
    resp = client.post(
        "/api/auth/register",
        json={"name": "Test User", "email": email, "password": password},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _set_renew_at(email, days_remaining):
    """Set renew_at so the endpoint's (midnight-truncated) days_remaining computation
    yields exactly `days_remaining`, regardless of what time of day the test runs.

    The endpoint parses renew_at as midnight of a calendar date and diffs it against
    the full current timestamp, then truncates to whole days. Whatever time "now" is
    today, the gap to midnight `days_remaining + 1` calendar days ahead always lies in
    (days_remaining, days_remaining + 1], which truncates to `days_remaining`.
    """
    target_date = datetime.today() + timedelta(days=days_remaining + 1)
    billing_data[email]["renew_at"] = target_date.strftime("%b %d, %Y")


# ---------------------------------------------------------------------------
# AC-2 / REQ-F-04 / ARCH-01: server-side proration math
# ---------------------------------------------------------------------------

def test_charge_card_deterministic_success():
    assert charge_card("priya@example.com", 10.0) == {"status": "success"}
    # Deterministic: repeated calls with the same email give the same result.
    assert charge_card("priya@example.com", 10.0) == {"status": "success"}


def test_charge_card_deterministic_decline():
    result = charge_card("fail@example.com", 10.0)
    assert result["status"] == "card_declined"
    assert result["message"] == "Your card was declined."


def test_upgrade_preview_computes_exact_proration_from_epic_example():
    email = _new_email("preview")
    _register(email)
    _set_renew_at(email, 15)

    resp = client.get(f"/api/billing/upgrade-preview?email={email}")

    assert resp.status_code == 200
    body = resp.json()
    assert body["current_plan"] == "Standard"
    assert body["new_plan"] == "Premium"
    assert body["days_remaining"] == 15
    assert body["prorated_charge"] == 10.00
    assert body["next_renewal_price"] == 40.00


def test_upgrade_preview_unknown_email_is_401():
    resp = client.get("/api/billing/upgrade-preview?email=nobody@example.com")
    assert resp.status_code == 401


def test_upgrade_unknown_email_is_401():
    resp = client.post("/api/billing/upgrade", json={"email": "nobody@example.com"})
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# AC-4 / REQ-F-06 / REQ-F-07 / REQ-F-09: happy path execution
# ---------------------------------------------------------------------------

def test_upgrade_success_flips_plan_and_quotas():
    email = _new_email("happy")
    _register(email)
    _set_renew_at(email, 15)

    resp = client.post("/api/billing/upgrade", json={"email": email})

    assert resp.status_code == 200
    body = resp.json()
    assert body == {"status": "success", "plan": "Premium", "charge": 10.00}

    assert users[email]["plan"] == "Premium"
    assert users[email]["price"] == "$40/month"

    record = billing_data[email]
    assert record["plan_name"] == "Premium"
    assert record["price"] == "$40/month"
    assert record["on_demand_usage"]["notice"] == "On-demand credit is available on your Premium plan."

    usages_by_id = {u["id"]: u for u in record["usages"]}
    assert usages_by_id["chat-credits"]["total"] == 10000
    assert usages_by_id["chatbots"]["total"] == 10
    assert usages_by_id["documents-pages"]["total"] == 5000
    # renew_at is preserved unchanged by the upgrade (REQ epic-level AC).
    assert record["renew_at"] == (datetime.today() + timedelta(days=16)).strftime("%b %d, %Y")


def test_billing_endpoint_reflects_premium_after_upgrade():
    email = _new_email("refresh")
    _register(email)
    _set_renew_at(email, 15)
    client.post("/api/billing/upgrade", json={"email": email})

    resp = client.get(f"/api/billing?email={email}")
    assert resp.status_code == 200
    assert resp.json()["plan_name"] == "Premium"


# ---------------------------------------------------------------------------
# AC-5 / REQ-F-06 / REQ-F-08: card-declined failure path
# ---------------------------------------------------------------------------

def test_upgrade_declined_leaves_plan_unchanged():
    email = _new_email("fail")
    email = f"fail{email}"  # ensure the "fail" prefix triggers the decline path
    _register(email)
    _set_renew_at(email, 15)

    resp = client.post("/api/billing/upgrade", json={"email": email})

    assert resp.status_code == 402
    body = resp.json()
    assert body["detail"] == "card_declined"
    assert body["message"] == "Your card was declined."

    assert users[email]["plan"] == "Standard"
    assert billing_data[email]["plan_name"] == "Standard"
    assert billing_data[email]["usages"][0]["total"] == 2000  # untouched Standard quota


# ---------------------------------------------------------------------------
# AC-5 / REQ-F-10 / ARCH-04: already-Premium guard, first check on both endpoints
# ---------------------------------------------------------------------------

def test_preview_rejects_already_premium():
    email = _new_email("premium")
    _register(email)
    billing_data[email]["plan_name"] = "Premium"

    resp = client.get(f"/api/billing/upgrade-preview?email={email}")
    assert resp.status_code == 409
    assert resp.json()["detail"] == "already_premium"


def test_upgrade_rejects_already_premium_before_charging(monkeypatch):
    email = _new_email("premium2")
    _register(email)
    billing_data[email]["plan_name"] = "Premium"

    def _fail_if_called(*args, **kwargs):
        raise AssertionError("charge_card must not be called for an already-Premium user")

    monkeypatch.setattr(main, "charge_card", _fail_if_called)

    resp = client.post("/api/billing/upgrade", json={"email": email})
    assert resp.status_code == 409
    assert resp.json()["detail"] == "already_premium"
