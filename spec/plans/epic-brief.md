> **Source**: Helix Solution Document (not an external tracker — Tracker Type is LOCAL)
> **Server / tool**: helix MCP · get_solution_document_tool
> **Solution**: Billing-Cycle-AIRE-V1-Demo (solution_id 874)
> **Document**: "Epic: Mid-Cycle Subscription Upgrade (Standard → Premium).md" (document_id 3157, v1, artifact_type=epic)
> **Fetched**: 2026-09-03T11:26:15Z
> **Freshness**: created_at 2026-08-25T11:29:10Z, not updated since (lifecycle_state CURRENT)

# Epic: Mid-Cycle Subscription Upgrade (Standard → Premium)

**Project:** Billing-Cycle
**Created:** 2026-08-25
**For:** Shailendra
**Status:** Draft
**Source Analysis:** Deep Dive: Billing-Cycle.md

---

## Problem Statement

The Billing page currently shows a hardcoded `Standard` badge and a static plan card with no upgrade path. An active Standard subscriber ($20/mo) has no way to move to Premium ($40/mo) from within the application — even though `billing_data` and `users` in `backend/main.py` already carry `plan_name` and `price` fields designed to reflect the current plan.

This epic adds a self-serve upgrade flow: an **Upgrade Plan** CTA on the Billing page, a confirmation step showing the prorated charge, and a dummy in-repo payment gateway that deterministically exercises both the success and card-declined paths. No external payment SDK is involved.

---

## Goals

- Allow a Standard subscriber to upgrade to Premium in a single self-serve flow from the Billing page
- Charge only the prorated amount for days remaining in the current cycle at the time of upgrade
- Flip the plan to Premium immediately on payment success and update all quota values in `billing_data`
- Keep the user on Standard with a visible error on payment failure (card_declined)
- Keep everything demo-able locally with no external dependencies

---

## Out of Scope

- Downgrades (Premium → Standard)
- Refunds or credits
- Enterprise tier
- Real payment provider integration (Stripe, Braintree, etc.)
- Email receipts / notifications

---

## Pricing & Proration Specification

| Plan | Monthly Price |
|------|--------------|
| Standard | $20.00 |
| Premium | $40.00 |

**Proration formula:**

```
days_remaining  = (renew_at_date - today).days          # integer, >= 1
days_in_cycle   = 30                                     # fixed for POC
daily_delta     = (premium_price - standard_price) / days_in_cycle
prorated_charge = daily_delta x days_remaining
```

**Example (from requirements):**
15 days remaining -> `($40 - $20) / 30 x 15 = $10.00`

> `renew_at` is stored in `billing_data` as a formatted string (`"Sep 09, 2025"`). The backend must parse it with `datetime.strptime(renew_at, "%b %d, %Y")` to compute `days_remaining`.

---

## Dummy Payment Gateway Specification

A new internal module (or function in `backend/main.py` for POC) acts as the gateway. It accepts the email of the caller and returns a deterministic result based on a **trigger email prefix**:

| Email used at registration / login | Gateway result |
|------------------------------------|---------------|
| Any email **not** starting with `fail` | `{"status": "success"}` |
| Any email starting with `fail` (e.g. `fail@example.com`) | `{"status": "card_declined", "message": "Your card was declined."}` |

This lets both paths be demonstrated on demand without any UI toggle.
The gateway function signature: `def charge_card(email: str, amount: float) -> dict`

---

## User Stories

### Story 1 — Upgrade CTA on Billing Page
**As a Standard subscriber, I want to see an "Upgrade to Premium" button on the Billing page so I know an upgrade is available.**

**Acceptance Criteria:**
- The Billing page displays an "Upgrade to Premium" button when `billing_data[email]["plan_name"] == "Standard"`
- The button is not shown when `plan_name == "Premium"` (already on Premium)
- The hardcoded `<span className="standard-badge">Standard</span>` in `Billing.jsx` (line 128) is replaced with a dynamic value driven by the API response
- The plan card's `"Active"` badge and price update to reflect the real plan from `billing_data`

**Files Touched:**
- `frontend/src/pages/Billing.jsx` — add conditional CTA button; make plan badge dynamic
- `backend/main.py` — no change required for this story alone (plan already in `billing_data`)

---

### Story 2 — Proration Confirmation Modal
**As a Standard subscriber clicking "Upgrade to Premium", I want to see a confirmation step showing the exact prorated charge before I commit, so I'm not surprised by the amount.**

**Acceptance Criteria:**
- Clicking "Upgrade to Premium" opens a modal (or inline confirmation panel) — no page navigation
- Modal displays:
  - Current plan: Standard ($20/mo)
  - New plan: Premium ($40/mo)
  - Days remaining in current cycle (computed from `renew_at`)
  - Prorated charge amount (e.g. "You will be charged **$10.00** today")
  - Next renewal price: "$40.00/month starting [renew_at date]"
- Modal has two actions: **"Confirm Upgrade"** and **"Cancel"**
- Cancel closes the modal with no changes
- The prorated amount is fetched from the backend, not computed in the frontend

**New Backend Endpoint:**
`GET /api/billing/upgrade-preview?email=<email>`
Returns:
```json
{
  "current_plan": "Standard",
  "new_plan": "Premium",
  "days_remaining": 15,
  "prorated_charge": 10.00,
  "next_renewal_price": 40.00,
  "renew_at": "Sep 09, 2025"
}
```

**Files Touched:**
- `backend/main.py` — add `GET /api/billing/upgrade-preview` endpoint + proration logic
- `frontend/src/pages/Billing.jsx` — add modal state, fetch preview, render confirmation panel

---

### Story 3 — Execute Upgrade & Dummy Payment
**As a Standard subscriber who has confirmed the upgrade, I want the system to charge the prorated amount through the payment gateway and immediately flip my plan to Premium if payment succeeds.**

**Acceptance Criteria:**

*Happy path (email does NOT start with `fail`):*
- `POST /api/billing/upgrade` is called with `{"email": "..."}` on "Confirm Upgrade"
- Backend calls `charge_card(email, prorated_charge)` -> `{"status": "success"}`
- `users[email]["plan"]` updated to `"Premium"` and `users[email]["price"]` to `"$40/month"`
- `billing_data[email]["plan_name"]` updated to `"Premium"`, `"price"` to `"$40/month"`
- `billing_data[email]["usages"]` quotas updated to Premium values (see Story 4)
- `billing_data[email]["on_demand_usage"]["notice"]` updated to remove the Standard-plan on-demand restriction notice
- Endpoint returns `{"status": "success", "plan": "Premium", "charge": 10.00}`
- Billing page auto-refreshes (re-fetches `GET /api/billing`) and shows Premium plan, updated badge, new price, new quotas
- Upgrade button is gone (user is now on Premium)
- A success banner is shown: "You're now on Premium! $10.00 was charged."

*Failure path (email starts with `fail`):*
- Backend calls `charge_card(email, prorated_charge)` -> `{"status": "card_declined", ...}`
- Endpoint returns HTTP 402 with `{"detail": "card_declined", "message": "Your card was declined."}`
- User remains on Standard (no plan change)
- Error message shown inline in the modal: "Payment failed: Your card was declined. Your plan has not changed."
- Modal stays open so user can cancel

**New Backend Endpoint:**
`POST /api/billing/upgrade` — body: `{"email": str}`

**Files Touched:**
- `backend/main.py` — add `charge_card()` function, add `POST /api/billing/upgrade` endpoint, add `UpgradeRequest` Pydantic model
- `frontend/src/pages/Billing.jsx` — call upgrade endpoint on confirm, handle success/failure states, show banner or error

---

### Story 4 — Premium Plan Quotas & Billing Data
**As a newly upgraded Premium subscriber, I want the Billing page to show my Premium-tier quotas and the correct plan price immediately after upgrade.**

**Acceptance Criteria:**
- After a successful upgrade, `billing_data[email]["usages"]` reflects Premium values:

| Metric | Standard | Premium |
|--------|---------|---------|
| Chat credits | 2,000 | 10,000 |
| Chatbots | 3 | 10 |
| Document pages | 1,000 | 5,000 |

- `on_demand_usage.notice` changes from the Standard restriction message to: `"On-demand credit is available on your Premium plan."`
- Plan card shows: plan name "Premium", price "$40/month", badge "Active"
- The `"Current plan:"` label shows a `Premium` badge instead of `Standard`

**Files Touched:**
- `backend/main.py` — `POST /api/billing/upgrade` mutates `billing_data` with above quota values
- `frontend/src/pages/Billing.jsx` — plan badge must be driven by `data.plan_name` (not the hardcoded string `"Standard"` on line 128)

---

### Story 5 — Already-Premium Guard
**As a Premium subscriber visiting the Billing page, I should not see the upgrade button, so I'm not confused into attempting a redundant upgrade.**

**Acceptance Criteria:**
- When `billing_data[email]["plan_name"] == "Premium"`, the Billing page shows no "Upgrade to Premium" button
- `GET /api/billing/upgrade-preview` for a Premium user returns HTTP 409 with `{"detail": "already_premium"}`
- `POST /api/billing/upgrade` for a Premium user returns HTTP 409 with `{"detail": "already_premium"}`

**Files Touched:**
- `backend/main.py` — guard both upgrade endpoints against already-Premium users
- `frontend/src/pages/Billing.jsx` — conditional render of CTA based on `data.plan_name`

---

## Technical Design Notes

### Backend Changes to `backend/main.py`

**New Pydantic model:**
```python
class UpgradeRequest(BaseModel):
    email: str
```

**New constant block (add near top, after imports):**
```python
PLANS = {
    "Standard": {"price": 20.0, "label": "$20/month"},
    "Premium":  {"price": 40.0, "label": "$40/month"},
}
PREMIUM_QUOTAS = {
    "usages": [
        {"id": "chat-credits",     "label": "Chat credits",     "used": 0, "total": 10000, "help": "Messages used this billing cycle."},
        {"id": "chatbots",         "label": "Chatbots",         "used": 0, "total": 10,    "help": "Active chatbot agents out of the included limit."},
        {"id": "documents-pages",  "label": "Documents pages",  "used": 0, "total": 5000,  "help": "You can add 5000 more pages of your documents."},
    ]
}
DAYS_IN_CYCLE = 30
```

**New dummy gateway function:**
```python
def charge_card(email: str, amount: float) -> dict:
    if email.startswith("fail"):
        return {"status": "card_declined", "message": "Your card was declined."}
    return {"status": "success"}
```

**New endpoints:**
```
GET  /api/billing/upgrade-preview?email=<str>
POST /api/billing/upgrade   body: UpgradeRequest
```

**Proration logic (in upgrade-preview and upgrade):**
```python
renew_at_date = datetime.strptime(billing_data[email]["renew_at"], "%b %d, %Y")
days_remaining = max(1, (renew_at_date - datetime.today()).days)
daily_delta = (PLANS["Premium"]["price"] - PLANS["Standard"]["price"]) / DAYS_IN_CYCLE
prorated_charge = round(daily_delta * days_remaining, 2)
```

### Frontend Changes to `frontend/src/pages/Billing.jsx`

1. **Remove hardcoded `"Standard"` badge** (line 128) — replace with `data.plan_name`
2. **Conditional "Upgrade to Premium" CTA** — rendered when `data.plan_name === "Standard"`
3. **Upgrade modal state** — `useState` for `{ open, preview, loading, error, success }`
4. **`fetchUpgradePreview()`** — calls `GET /api/billing/upgrade-preview?email=...` when CTA is clicked
5. **`confirmUpgrade()`** — calls `POST /api/billing/upgrade`, handles success (re-fetch billing, show banner, close modal) and failure (show error in modal)

---

## Acceptance Criteria — Epic Level

- [ ] Standard subscriber sees "Upgrade to Premium" button on the Billing page
- [ ] Clicking the button opens a confirmation modal with the exact prorated amount
- [ ] Confirming the upgrade with a non-`fail` email succeeds: plan flips to Premium, quotas update, page refreshes, success banner shown
- [ ] Confirming with a `fail*` email fails: user stays on Standard, error shown in modal, no data mutated
- [ ] Already-Premium users see no upgrade button and get HTTP 409 on both upgrade endpoints
- [ ] `renew_at` date is preserved unchanged after upgrade (next full cycle still bills at renewal date)
- [ ] The dummy gateway is deterministic and requires no external service or SDK
- [ ] All proration math runs server-side; frontend only displays the value returned by the API
- [ ] No changes to auth, tasks, login, or registration flows

---

## Story Summary & Effort Estimates

| # | Story | Effort |
|---|-------|--------|
| 1 | Upgrade CTA on Billing Page | 0.5 day |
| 2 | Proration Confirmation Modal | 1 day |
| 3 | Execute Upgrade & Dummy Payment | 1 day |
| 4 | Premium Quotas & Billing Data | 0.5 day |
| 5 | Already-Premium Guard | 0.5 day |
| **Total** | | **~3.5 days** |

---

## Referenced Paths

### High Relevance
- `Billing-Cycle/backend/main.py` — Source of truth for all data structures (`users`, `billing_data`), plan fields, `renew_at` format, and all existing endpoints
- `Billing-Cycle/frontend/src/pages/Billing.jsx` — Hardcoded "Standard" badge (line 128), plan card layout, fetch pattern, state shape
- `Billing-Cycle/frontend/src/context/AuthContext.jsx` — Token = email pattern; `token` is used as the email param in all API calls

### Medium Relevance
- `Billing-Cycle/frontend/src/App.jsx` — Route structure and ProtectedRoute guard (no changes required)
- `Billing-Cycle/backend/requirements.txt` — No new dependencies required for this epic

### Low Relevance
- `Billing-Cycle/frontend/package.json` — No new npm packages required
- `Billing-Cycle/frontend/vite.config.js` — Existing `/api` proxy covers all new endpoints
