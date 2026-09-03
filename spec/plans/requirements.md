# Requirements — Mid-Cycle Subscription Upgrade (Standard → Premium)

## Intent Analysis Summary
- **User request**: "using aire and helix mcp fetch the solution document and implement the epic requirements"
- **Request type**: New Feature (self-serve billing upgrade flow) on an existing brownfield system
- **Scope estimate**: Multiple components — `backend/main.py` (2 new endpoints, new gateway function, new constants) + `frontend/src/pages/Billing.jsx` (CTA, modal, state, refetch)
- **Complexity estimate**: Moderate — deterministic proration math, a dummy payment gateway with two outcomes, and 3 plan-state guards (Standard-only CTA, already-Premium 409, failure path leaves state untouched)
- **Source**: `spec/plans/epic-brief.md`, fetched verbatim from Helix solution document 3157 (artifact_type=epic). The Epic is exceptionally clear and complete — no core clarifying questions were needed (see `spec/plans/requirement-verification-questions.md`).
- **Extensions**: Resiliency Baseline = No, Property-Based Testing = No (both declined — POC scope, not production-critical). Security Baseline and Playwright Test Automation remain always-mandatory.

---

## Functional Requirements

- **REQ-F-01**: The Billing page displays an "Upgrade to Premium" CTA when the current user's `billing_data[email]["plan_name"] == "Standard"`, and hides it when `== "Premium"`.
- **REQ-F-02**: The hardcoded `<span className="standard-badge">Standard</span>` (Billing.jsx line 128) and the plan card's "Active" badge/price are replaced with values driven dynamically by the `GET /api/billing` response.
- **REQ-F-03**: Clicking the CTA opens a confirmation modal (no page navigation) that fetches and displays, from a new `GET /api/billing/upgrade-preview?email=<email>` endpoint: current plan, new plan, days remaining in the current cycle, the prorated charge, and the next renewal price/date. The frontend never computes proration itself.
- **REQ-F-04**: The proration calculation is: `days_remaining = max(1, (renew_at_date - today).days)`, `renew_at` parsed with `strptime(renew_at, "%b %d, %Y")`; `daily_delta = (Premium.price - Standard.price) / 30`; `prorated_charge = round(daily_delta * days_remaining, 2)`.
- **REQ-F-05**: The modal offers "Confirm Upgrade" and "Cancel". Cancel closes the modal with zero side effects.
- **REQ-F-06**: Confirming calls `POST /api/billing/upgrade` with `{"email": ...}`, which calls the dummy gateway `charge_card(email, prorated_charge) -> dict`: emails not starting with `fail` return `{"status": "success"}`; emails starting with `fail` return `{"status": "card_declined", "message": "Your card was declined."}`.
- **REQ-F-07 (happy path)**: On gateway success, the backend atomically updates `users[email]["plan"]`→`"Premium"`, `users[email]["price"]`→`"$40/month"`, `billing_data[email]["plan_name"]`→`"Premium"`, `billing_data[email]["price"]`→`"$40/month"`, `billing_data[email]["usages"]`→ Premium quotas (chat credits 10000, chatbots 10, document pages 5000), and `on_demand_usage.notice`→the Premium notice string. Returns `{"status": "success", "plan": "Premium", "charge": <prorated_charge>}`. Frontend re-fetches `GET /api/billing`, hides the CTA, and shows a success banner "You're now on Premium! $X.XX was charged."
- **REQ-F-08 (failure path)**: On gateway decline, the backend makes NO mutation to `users` or `billing_data`, and returns HTTP 402 `{"detail": "card_declined", "message": "Your card was declined."}`. The modal shows the error inline, stays open, and the user remains on Standard.
- **REQ-F-09**: `renew_at` is never modified by an upgrade — the next full billing cycle still renews on the original date.
- **REQ-F-10 (already-Premium guard)**: For a user already on Premium, both `GET /api/billing/upgrade-preview` and `POST /api/billing/upgrade` return HTTP 409 `{"detail": "already_premium"}`, and the frontend never renders the CTA for that user.
- **REQ-F-11**: No changes to auth, tasks, login, or registration flows or endpoints.

## Non-Functional Requirements

- **REQ-NF-01 (Correctness/Determinism)**: The gateway outcome (`charge_card`) must be 100% deterministic on the `fail` email prefix — no randomness, no external network call — so both paths are demoable on demand.
- **REQ-NF-02 (Consistency)**: The plan-flip mutation (users + billing_data + quotas + notice) on upgrade success must be atomic from the caller's perspective — never a partially-updated state visible to a subsequent `GET /api/billing`.
- **REQ-NF-03 (No new dependencies)**: The feature ships with zero new pip/npm packages and zero external services (confirmed by the Epic's Referenced Paths — `requirements.txt`, `package.json`, `vite.config.js` all require no change).
- **REQ-NF-04 (Security)**: New endpoints stay within the existing auth pattern (email/token as currently used by `AuthContext.jsx`); no new attack surface beyond what Security Baseline review already covers for `backend/main.py`.
- **REQ-NF-05 (Testability)**: Because the gateway result is keyed purely off the email prefix, both the success and card-declined paths must be independently coverable by unit and Gherkin behavior tests without mocking any external HTTP call.

---

## Design References Consulted
None registered — no separate wireframes/spec documents were supplied; the Epic's own "Technical Design Notes" section (endpoints, Pydantic model, constants, proration/gateway code) is the primary and sufficient design input, already folded into the requirements above.

## Context Project Artifacts Consulted
None — no `## Context Project` opt-in recorded.

## Summary

Five requirement groups (functional REQ-F-01…11, non-functional REQ-NF-01…05) fully specify a self-serve Standard→Premium upgrade: CTA visibility, a preview endpoint with server-side proration, an execute endpoint driving a deterministic dummy gateway, atomic success-path mutation of plan/quotas, a strict no-mutation failure path, and an already-Premium guard on both new endpoints. Scope is confined to `backend/main.py` and `frontend/src/pages/Billing.jsx` — confirmed by both the Epic's Referenced Paths and the Helix knowledge-graph query (`spec/plans/knowledge-graph.md`).
