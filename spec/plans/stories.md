EPIC TICKET: Helix Solution Document 3157 — "Epic: Mid-Cycle Subscription Upgrade (Standard → Premium)" (no external tracker — Type: LOCAL)

# Stories — Mid-Cycle Subscription Upgrade

> **target_story_count: 1** — a deliberate, user-confirmed override of the recommended 5-story SPIDR-sliced breakdown. See `spec/plans/story-generation-generation.md` and the trade-off confirmation logged in `runtime-artifacts/audit.md`. This story intentionally exceeds the Step 1.5 hard sizing ceilings (>5 ACs, multiple architectural layers, multiple scenario classes) as an explicit, informed exception — flagged here rather than auto-split.

---

## Story 1.1 — Self-Serve Mid-Cycle Upgrade: Standard → Premium

**As a Standard subscriber, I want to upgrade to Premium from the Billing page — see the exact prorated charge before committing, have it applied through a deterministic dummy payment gateway, and immediately see my new plan and quotas — so that I can move up mid-cycle without leaving the app, and so that Premium subscribers and failed payments are handled safely.**

**Persona**: Alex (Standard), Priya (Premium, guard), Dana (declined, failure path)

**Covers**: REQ-F-01, REQ-F-02, REQ-F-03, REQ-F-04, REQ-F-05, REQ-F-06, REQ-F-07, REQ-F-08, REQ-F-09, REQ-F-10, REQ-F-11, REQ-NF-01, REQ-NF-02, REQ-NF-03, REQ-NF-04, REQ-NF-05

### Acceptance Criteria (AC-n → REQ-ID)

- **AC-1** (→ REQ-F-01, REQ-F-02): Billing page shows an "Upgrade to Premium" CTA when `billing_data[email]["plan_name"] == "Standard"`; hidden when `== "Premium"`. The hardcoded `<span className="standard-badge">Standard</span>` (Billing.jsx line 128) and the plan card's badge/price are replaced with values driven by `GET /api/billing`.
- **AC-2** (→ REQ-F-03, REQ-F-04): Clicking the CTA opens a modal (no navigation) that calls `GET /api/billing/upgrade-preview?email=<email>` and displays current plan, new plan, days remaining, prorated charge, and next renewal price/date — all computed server-side using `days_remaining = max(1, (renew_at_date - today).days)` with `renew_at` parsed via `strptime("%b %d, %Y")`, `daily_delta = (40-20)/30`, `prorated_charge = round(daily_delta * days_remaining, 2)`.
- **AC-3** (→ REQ-F-05): Modal offers "Confirm Upgrade" / "Cancel"; Cancel closes the modal with zero backend calls or state changes.
- **AC-4** (→ REQ-F-06, REQ-F-07, REQ-NF-01, REQ-NF-02): Confirm calls `POST /api/billing/upgrade {email}` → `charge_card(email, prorated_charge)`. Non-`fail*` emails succeed deterministically: `users[email]` and `billing_data[email]` atomically update to Premium (plan, price, quotas — chat credits 10000, chatbots 10, document pages 5000 — and the on-demand notice text); endpoint returns `{"status":"success","plan":"Premium","charge":<amt>}`; frontend re-fetches `GET /api/billing`, hides the CTA, shows success banner "You're now on Premium! $X.XX was charged."
- **AC-5** (→ REQ-F-08, REQ-F-09, REQ-NF-01, REQ-NF-02): `fail*` emails deterministically decline: NO mutation to `users` or `billing_data` (verified by re-reading state after the call), HTTP 402 `{"detail":"card_declined","message":"Your card was declined."}`; modal shows the error inline and stays open; user remains on Standard; `renew_at` is unchanged in both the success and failure paths.
- **AC-6** (→ REQ-F-10): For a user already on Premium, both `GET /api/billing/upgrade-preview` and `POST /api/billing/upgrade` return HTTP 409 `{"detail":"already_premium"}`, and the CTA never renders for that user.
- **AC-7** (→ REQ-F-11, REQ-NF-03, REQ-NF-04): No changes to auth/tasks/login/registration endpoints or flows; zero new pip/npm dependencies; both new endpoints follow the existing email/token auth pattern from `AuthContext.jsx`.

**Files Touched** (per Epic Technical Design Notes, `spec/plans/epic-brief.md`):
- `backend/main.py` — `UpgradeRequest` Pydantic model; `PLANS`, `PREMIUM_QUOTAS`, `DAYS_IN_CYCLE` constants; `charge_card()`; `GET /api/billing/upgrade-preview`; `POST /api/billing/upgrade`
- `frontend/src/pages/Billing.jsx` — dynamic plan badge/price, conditional CTA, upgrade modal state, `fetchUpgradePreview()`, `confirmUpgrade()`

**Requires**: none (single story — see `spec/plans/dependency-graph.yml`)

**Granularity note (Step 1.5 / 18.6)**: This story exceeds the hard sizing ceilings (7 ACs > 5, two architectural layers newly touched, multiple scenario classes — happy path, failure path, guard path). This is a **deliberate, user-confirmed exception**, not an oversight — logged in `runtime-artifacts/audit.md`. No further AI-driven split will be applied unless the user requests one.

---

## Requirements Coverage Matrix

| REQ-ID | Covering Stories | Status |
|---|---|---|
| REQ-F-01 | 1.1 (AC-1) | ✅ Full |
| REQ-F-02 | 1.1 (AC-1) | ✅ Full |
| REQ-F-03 | 1.1 (AC-2) | ✅ Full |
| REQ-F-04 | 1.1 (AC-2) | ✅ Full |
| REQ-F-05 | 1.1 (AC-3) | ✅ Full |
| REQ-F-06 | 1.1 (AC-4) | ✅ Full |
| REQ-F-07 | 1.1 (AC-4) | ✅ Full |
| REQ-F-08 | 1.1 (AC-5) | ✅ Full |
| REQ-F-09 | 1.1 (AC-5) | ✅ Full |
| REQ-F-10 | 1.1 (AC-6) | ✅ Full |
| REQ-F-11 | 1.1 (AC-7) | ✅ Full |
| REQ-NF-01 | 1.1 (AC-4, AC-5) | ✅ Full |
| REQ-NF-02 | 1.1 (AC-4, AC-5) | ✅ Full |
| REQ-NF-03 | 1.1 (AC-7) | ✅ Full |
| REQ-NF-04 | 1.1 (AC-7) | ✅ Full |
| REQ-NF-05 | 1.1 (AC-4, AC-5) | ✅ Full |

**Coverage**: 16/16 REQ-IDs fully covered by story ACs.
