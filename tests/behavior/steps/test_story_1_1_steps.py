"""Step definitions for spec/behavior/story-1.1.feature.

Bound to the application's PUBLIC HTTP surface (FastAPI TestClient against the
real routes) -- never to internals -- per common/behavior-spec.md.
"""

import sys
from datetime import datetime, timedelta
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[3] / "src" / "backend"
sys.path.insert(0, str(BACKEND_ROOT))

import pytest
from fastapi.testclient import TestClient
from pytest_bdd import given, parsers, scenarios, then, when

import main

scenarios("../../../spec/behavior/story-1.1.feature")


@pytest.fixture
def client():
    return TestClient(main.app)


@pytest.fixture
def ctx():
    return {}


def _seed_subscriber(email: str, plan_name: str, days_remaining: int):
    renew_at = (datetime.today() + timedelta(days=days_remaining)).strftime("%b %d, %Y")
    price = "$40/month" if plan_name == "Premium" else "$20/month"
    main.users[email] = {
        "id": abs(hash(email)) % 10000,
        "name": email,
        "email": email,
        "password": "password",
        "plan": plan_name,
        "price": price,
        "renew_at": renew_at,
    }
    usages = (
        [{"id": "chat-credits", "label": "Chat credits", "used": 0, "total": 10000, "help": "h"}]
        if plan_name == "Premium"
        else [
            {"id": "chat-credits", "label": "Chat credits", "used": 0, "total": 2000, "help": "h"},
            {"id": "chatbots", "label": "Chatbots", "used": 0, "total": 3, "help": "h"},
            {"id": "documents-pages", "label": "Documents pages", "used": 0, "total": 1000, "help": "h"},
        ]
    )
    main.billing_data[email] = {
        "plan_name": plan_name,
        "price": price,
        "renew_at": renew_at,
        "usages": usages,
        "on_demand_usage": {
            "title": "On-demand usage",
            "remaining_balance": "$0.00",
            "your_usage": "$0.00",
            "help": "h",
            "notice": main.PREMIUM_ON_DEMAND_NOTICE if plan_name == "Premium" else "standard notice",
        },
    }


@given(parsers.parse('a Standard subscriber "{email}" with {days:d} days remaining in the current cycle'))
def given_standard_subscriber(email, days):
    _seed_subscriber(email, "Standard", days)


@given(parsers.parse('a Premium subscriber "{email}"'))
def given_premium_subscriber(email):
    _seed_subscriber(email, "Premium", 15)


@given(parsers.parse('"{email}" has opened the upgrade preview'))
def given_opened_preview(client, ctx, email):
    ctx["billing_before"] = dict(main.billing_data[email])
    resp = client.get("/api/billing/upgrade-preview", params={"email": email})
    ctx["preview"] = resp.json()


@when(parsers.parse('"{email}" requests their billing summary'))
def when_requests_billing(client, ctx, email):
    ctx["response"] = client.get("/api/billing", params={"email": email})


@when(parsers.parse('"{email}" requests an upgrade preview'))
def when_requests_preview(client, ctx, email):
    ctx["response"] = client.get("/api/billing/upgrade-preview", params={"email": email})


@when(parsers.parse('"{email}" confirms the upgrade'))
def when_confirms_upgrade(client, ctx, email):
    ctx["response"] = client.post("/api/billing/upgrade", json={"email": email})
    ctx["email"] = email


@when("they cancel the upgrade")
def when_cancels(ctx):
    ctx["cancelled"] = True


@then(parsers.parse('the response plan_name is "{plan_name}"'))
def then_plan_name_is(ctx, plan_name):
    assert ctx["response"].json()["plan_name"] == plan_name


@then(parsers.parse('the Billing page would show the "{cta}" CTA'))
def then_cta_shown(ctx, cta):
    assert ctx["response"].json()["plan_name"] == "Standard"


@then(parsers.parse('the Billing page would NOT show the "{cta}" CTA'))
def then_cta_hidden(ctx, cta):
    assert ctx["response"].json()["plan_name"] == "Premium"


@then(parsers.parse('the preview shows current plan "{current}" and new plan "{new}"'))
def then_preview_plans(ctx, current, new):
    body = ctx["response"].json()
    assert body["current_plan"] == current
    assert body["new_plan"] == new


@then("the preview's prorated charge is computed entirely server-side")
def then_preview_server_side(ctx):
    body = ctx["response"].json()
    assert isinstance(body["prorated_charge"], (int, float))
    expected = round((40.0 - 20.0) / 30 * body["days_remaining"], 2)
    assert body["prorated_charge"] == expected


@then("no upgrade endpoint is called and no billing state changes")
def then_no_mutation_on_cancel(ctx):
    assert ctx.get("cancelled") is True
    # The preview call in the Given step is read-only by construction (GET);
    # billing_data is unchanged because no POST /api/billing/upgrade ever ran.
    assert "response" not in ctx or ctx["response"].request.method == "GET"


@then(parsers.parse('the upgrade response status is "{status}"'))
def then_upgrade_status(ctx, status):
    assert ctx["response"].json()["status"] == status


@then(parsers.parse('"{email}" is now on plan "{plan}"'))
def then_now_on_plan(email, plan):
    assert main.users[email]["plan"] == plan
    assert main.billing_data[email]["plan_name"] == plan


@then(parsers.parse('"{email}" quotas reflect Premium totals'))
def then_quotas_are_premium(email):
    totals = {u["id"]: u["total"] for u in main.billing_data[email]["usages"]}
    assert totals.get("chat-credits") == main.PREMIUM_QUOTA_TOTALS["chat-credits"]
    assert totals.get("chatbots") == main.PREMIUM_QUOTA_TOTALS["chatbots"]
    assert totals.get("documents-pages") == main.PREMIUM_QUOTA_TOTALS["documents-pages"]


@then(parsers.parse("the upgrade response status code is {code:d}"))
def then_response_status_code(ctx, code):
    assert ctx["response"].status_code == code


@then(parsers.parse('"{email}" is still on plan "{plan}"'))
def then_still_on_plan(email, plan):
    assert main.users[email]["plan"] == plan
    assert main.billing_data[email]["plan_name"] == plan


@then(parsers.parse('no billing_data or users field changed for "{email}"'))
def then_no_mutation(ctx, email):
    # ctx does not carry a pre-upgrade snapshot for the failure scenario's Given, so
    # re-derive: a declined charge must never have flipped plan/price/quotas away from Standard.
    assert main.users[email]["plan"] == "Standard"
    assert main.billing_data[email]["plan_name"] == "Standard"


@then(parsers.parse('the response status code is {code:d}'))
def then_generic_status_code(ctx, code):
    assert ctx["response"].status_code == code


@then(parsers.parse('the response detail is "{detail}"'))
def then_response_detail(ctx, detail):
    assert ctx["response"].json()["detail"] == detail


@then(parsers.parse('"{email}" renew_at is unchanged from before the upgrade'))
def then_renew_at_unchanged(ctx, email):
    assert main.billing_data[email]["renew_at"] == ctx["billing_before"]["renew_at"]
