"""API & Contract Testing Gate evidence for Story 1.1's two new endpoints
(GET /api/billing/upgrade-preview, POST /api/billing/upgrade).

Checklist covered here: functional/happy path, response-code validation,
error-response validation, request validation, response contract/schema
validation. Role-based authorization (401 vs 403) is N/A -- this application
has no role system, only an authenticated/unauthenticated email check (401),
consistent with every other endpoint already in main.py.
"""

import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient

import main


@pytest.fixture(autouse=True)
def seed():
    main.users["contract@example.com"] = {
        "id": 200,
        "name": "Contract User",
        "email": "contract@example.com",
        "password": "password",
        "plan": "Standard",
        "price": "$20/month",
        "renew_at": (datetime.today() + timedelta(days=10)).strftime("%b %d, %Y"),
    }
    main.billing_data["contract@example.com"] = {
        "plan_name": "Standard",
        "price": "$20/month",
        "renew_at": main.users["contract@example.com"]["renew_at"],
        "usages": [{"id": "chat-credits", "label": "Chat credits", "used": 0, "total": 2000, "help": "h"}],
        "on_demand_usage": {
            "title": "On-demand usage",
            "remaining_balance": "$18.00",
            "your_usage": "$0.00",
            "help": "h",
            "notice": "standard notice",
        },
    }
    yield
    main.users.pop("contract@example.com", None)
    main.billing_data.pop("contract@example.com", None)


@pytest.fixture
def client():
    return TestClient(main.app)


# --- Response-code validation --------------------------------------------------


def test_preview_response_code_200_on_success(client):
    assert client.get("/api/billing/upgrade-preview", params={"email": "contract@example.com"}).status_code == 200


def test_preview_response_code_401_unauthenticated(client):
    assert client.get("/api/billing/upgrade-preview", params={"email": "ghost@example.com"}).status_code == 401


def test_upgrade_response_code_200_on_success(client):
    assert client.post("/api/billing/upgrade", json={"email": "contract@example.com"}).status_code == 200


def test_upgrade_response_code_401_unauthenticated(client):
    assert client.post("/api/billing/upgrade", json={"email": "ghost@example.com"}).status_code == 401


def test_upgrade_response_code_402_on_decline():
    main.users["failcontract@example.com"] = dict(main.users["contract@example.com"], email="failcontract@example.com")
    main.billing_data["failcontract@example.com"] = dict(main.billing_data["contract@example.com"])
    try:
        client = TestClient(main.app)
        resp = client.post("/api/billing/upgrade", json={"email": "failcontract@example.com"})
        assert resp.status_code == 402
    finally:
        main.users.pop("failcontract@example.com", None)
        main.billing_data.pop("failcontract@example.com", None)


# --- Request validation (Pydantic) ---------------------------------------------


def test_upgrade_request_validation_missing_email_field(client):
    resp = client.post("/api/billing/upgrade", json={})
    assert resp.status_code == 422  # FastAPI/Pydantic request validation


def test_upgrade_request_validation_wrong_type(client):
    resp = client.post("/api/billing/upgrade", json={"email": 12345})
    assert resp.status_code == 422


def test_preview_request_validation_missing_query_param(client):
    resp = client.get("/api/billing/upgrade-preview")
    assert resp.status_code == 422


# --- Response contract / schema validation -------------------------------------


def test_preview_response_schema(client):
    body = client.get("/api/billing/upgrade-preview", params={"email": "contract@example.com"}).json()
    for key in ("current_plan", "new_plan", "days_remaining", "prorated_charge", "next_renewal_price", "renew_at"):
        assert key in body
    assert isinstance(body["days_remaining"], int)
    assert isinstance(body["prorated_charge"], (int, float))
    assert isinstance(body["next_renewal_price"], (int, float))


def test_upgrade_success_response_schema(client):
    body = client.post("/api/billing/upgrade", json={"email": "contract@example.com"}).json()
    for key in ("status", "plan", "charge"):
        assert key in body
    assert body["status"] == "success"
    assert body["plan"] == "Premium"
    assert isinstance(body["charge"], (int, float))


# --- Error-response validation (standard format + codes) -----------------------


def test_already_premium_error_shape(client):
    client.post("/api/billing/upgrade", json={"email": "contract@example.com"})  # now Premium
    resp = client.get("/api/billing/upgrade-preview", params={"email": "contract@example.com"})
    assert resp.status_code == 409
    assert resp.json() == {"detail": "already_premium"}


def test_unauthenticated_error_shape(client):
    resp = client.get("/api/billing/upgrade-preview", params={"email": "ghost@example.com"})
    assert resp.status_code == 401
    assert "detail" in resp.json()


# --- Role-based authorization -- N/A (no role system in this app) --------------


def test_role_based_authorization_not_applicable():
    """This application has no role/permission model -- every endpoint (including the
    pre-existing /api/billing, /api/tasks) gates only on `email in users` (401), never
    on a role (403). Story 1.1's two new endpoints follow the identical existing
    convention. Recorded as N/A per code-generation.md's API & Contract Testing Gate
    checklist, not skipped silently."""
    assert True
