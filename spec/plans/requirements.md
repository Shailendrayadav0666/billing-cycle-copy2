# Requirements — Mid-Cycle Subscription Upgrade (Standard → Premium)

## Intent Analysis
- **User Request**: "using aire and helix mcp fetch the solution document and start implementing the epic requirements"
- **Request Type**: New Feature (self-serve subscription upgrade flow) on an existing brownfield app
- **Scope Estimate**: Multiple Components — one backend module (`src/backend/main.py`) and one frontend page (`src/frontend/src/pages/Billing.jsx`)
- **Complexity Estimate**: Simple — a bounded feature with a fully-specified, code-verified Epic and no external integrations
- **Depth Applied**: Minimal/Standard — the Epic solution document (Atlas, Helix MCP) was already exhaustive, verified line-for-line against the current `main.py` and `Billing.jsx`, so no clarifying-questions file was needed for functional scope. Two mandatory extension opt-in questions were still asked (see below).

## Source
- Primary input: `spec/plans/epic-brief.md` (Atlas solution document id 3157, fetched via Helix MCP)
- Current-system truth: `spec/plans/deep-dive.md` (Atlas solution document id 3155, Deep Dive, 13/13 steps COMPLETE)
- Verified directly against `src/backend/main.py` and `src/frontend/src/pages/Billing.jsx` — the Epic's referenced line numbers, data shapes, and function signatures match the current code exactly (no drift).

## Extension Configuration
| Extension | Enabled | Decided At |
|---|---|---|
| Resiliency Baseline | No | Requirements Analysis |
| Property-Based Testing | No | Requirements Analysis |
| Security Baseline | Yes (always mandatory) | Workflow start |
| Playwright Test Automation | Yes (always mandatory) | Workflow start |

## Functional Requirements

- **REQ-F-01**: The Billing page SHALL display an "Upgrade to Premium" CTA button when the current user's `plan_name` is `"Standard"`, and SHALL NOT display it when `plan_name` is `"Premium"`.
- **REQ-F-02**: The Billing page's plan badge and price SHALL be driven dynamically by the `GET /api/billing` response (`plan_name`), replacing the hardcoded `"Standard"` string currently at `Billing.jsx:128`.
- **REQ-F-03**: Clicking "Upgrade to Premium" SHALL open a confirmation modal (no page navigation) showing: current plan + price, new plan + price, days remaining in the cycle, the prorated charge, and the next renewal price/date — all values sourced from the backend, never computed client-side.
- **REQ-F-04**: A new endpoint `GET /api/billing/upgrade-preview?email=<email>` SHALL return `{current_plan, new_plan, days_remaining, prorated_charge, next_renewal_price, renew_at}` computed server-side using the proration formula: `daily_delta = (40 - 20) / 30`; `days_remaining = max(1, (renew_at_date - today).days)`; `prorated_charge = round(daily_delta * days_remaining, 2)`, parsing `renew_at` with `strptime(..., "%b %d, %Y")`.
- **REQ-F-05**: The confirmation modal SHALL offer "Confirm Upgrade" and "Cancel" actions; Cancel SHALL close the modal with no backend call and no state change.
- **REQ-F-06**: A new endpoint `POST /api/billing/upgrade` (body `{email: str}`) SHALL call a dummy gateway function `charge_card(email: str, amount: float) -> dict` that deterministically returns `{"status": "success"}` unless `email` starts with `"fail"`, in which case it returns `{"status": "card_declined", "message": "Your card was declined."}`.
- **REQ-F-07**: On gateway success, the backend SHALL: set `users[email]["plan"] = "Premium"` and `users[email]["price"] = "$40/month"`; set `billing_data[email]["plan_name"] = "Premium"` and `"price" = "$40/month"`; replace `billing_data[email]["usages"]` with Premium quotas (chat credits 10000, chatbots 10, document pages 5000, `used` reset to 0); update `on_demand_usage.notice` to `"On-demand credit is available on your Premium plan."`; leave `renew_at` unchanged; and return `{"status": "success", "plan": "Premium", "charge": <prorated_charge>}`.
- **REQ-F-08**: On gateway decline, the backend SHALL leave `users`/`billing_data` unmodified and return HTTP 402 with `{"detail": "card_declined", "message": "Your card was declined."}`.
- **REQ-F-09**: On success, the frontend SHALL re-fetch `GET /api/billing`, close the modal, hide the upgrade CTA, and show a success banner ("You're now on Premium! $X.XX was charged."). On failure, the frontend SHALL keep the modal open and show the inline error message; no plan/badge/usage state changes.
- **REQ-F-10**: Both `GET /api/billing/upgrade-preview` and `POST /api/billing/upgrade` SHALL return HTTP 409 with `{"detail": "already_premium"}` when the target user's `plan_name` is already `"Premium"`; the frontend SHALL NOT render the upgrade CTA for a Premium user in the first place (belt-and-suspenders guard).

## Non-Functional Requirements

- **REQ-NF-01** (Determinism): The dummy payment gateway MUST be fully deterministic (keyed only on the `email` prefix) — no randomness, no timers, no external network calls — so both the success and decline paths are reproducible on demand for demos and tests.
- **REQ-NF-02** (No new dependencies): No new backend or frontend package SHALL be added; the existing FastAPI + Pydantic + React/Vite stack and the existing `/api` Vite proxy cover the new endpoints.
- **REQ-NF-03** (Isolation): No change SHALL touch `/api/auth/*`, `/api/tasks*`, `/api/users/me`, or `AuthContext.jsx` — the upgrade flow is additive only to billing.
- **REQ-NF-04** (Server-side authority): All monetary/proration computation MUST happen server-side; the frontend only renders values returned by the API (never recomputes them), per REQ-F-03/REQ-F-04.
- **REQ-NF-05** (Security baseline): The two new endpoints follow the mandatory Security Baseline — input validation on `email`/request bodies via Pydantic, no secrets/PII beyond email in logs, and consistent error-response shapes (`detail`/`message`), matching the existing endpoints' conventions in `main.py`.

## Out of Scope (carried from Epic)
- Downgrades (Premium → Standard), refunds/credits, an Enterprise tier, a real payment provider (Stripe/Braintree/etc.), email receipts/notifications.

## Traceability
Every downstream story, test, and code-review finding references requirements ONLY by these REQ-IDs (`common/requirements-traceability.md` Rule 1). IDs are permanent once assigned.
