EPIC TICKET: Epic: Mid-Cycle Subscription Upgrade (Standard -> Premium) — Helix solution doc id 3157 (LOCAL tracker, no external URL)

> **Story-count override**: AIRE recommended slicing this Epic into 6 SPIDR-sized stories (see
> `spec/spec-generation/story-generation-generation.md`) so >=2 stories could run in parallel
> (`team_size: 2`) and each stayed within the Step 1.5 hard sizing ceilings. The user explicitly
> overrode this twice, after being shown the parallelism/sizing trade-off, and directed a single
> story. Recorded as an explicit user override in `runtime-artifacts/audit.md`; the granularity
> check (Step 18.6) below documents the resulting ceiling violations rather than auto-splitting.

---

## Story 1 — Mid-Cycle Subscription Upgrade (Standard → Premium)

**As** Priya, a Standard subscriber, **I want** a single self-serve flow on the Billing page to preview and confirm an upgrade to Premium, be charged only the prorated amount, and see my plan/quotas update immediately — **so that** I don't have to contact support or wait for renewal, and I know the exact charge before committing.

**Covers**: REQ-F-01, REQ-F-02, REQ-F-03, REQ-F-04, REQ-F-05, REQ-F-06, REQ-F-07, REQ-F-08, REQ-F-09, REQ-F-10, REQ-NF-01, REQ-NF-02, REQ-NF-03, REQ-NF-04, REQ-NF-05

**Persona**: Priya (Standard Subscriber) for the upgrade flow; Devraj (Premium Subscriber) for the already-premium guard.

### Acceptance Criteria

**AC-1 — CTA & dynamic plan badge** (REQ-F-01, REQ-F-02)
- The Billing page shows an "Upgrade to Premium" button only when `GET /api/billing` returns `plan_name == "Standard"`.
- The plan badge/price on the page is driven by `data.plan_name`/`data.price` — the hardcoded `<span className="standard-badge">Standard</span>` (`Billing.jsx:128`) is removed.

**AC-2 — Proration preview** (REQ-F-03, REQ-F-04, REQ-NF-04)
- Clicking the CTA opens a modal (no navigation) that calls `GET /api/billing/upgrade-preview?email=<email>`.
- The endpoint computes server-side: `days_remaining = max(1, (renew_at_date - today).days)` (parsing `renew_at` with `strptime(renew_at, "%b %d, %Y")`), `daily_delta = (40 - 20) / 30`, `prorated_charge = round(daily_delta * days_remaining, 2)`, and returns `{current_plan, new_plan, days_remaining, prorated_charge, next_renewal_price, renew_at}`.
- The modal renders all values from the response only — no client-side math.

**AC-3 — Confirm / Cancel** (REQ-F-05)
- The modal offers "Confirm Upgrade" and "Cancel". Cancel closes the modal with zero backend calls and zero state change.

**AC-4 — Execute upgrade: happy path** (REQ-F-06, REQ-F-07, REQ-F-09, REQ-NF-01, REQ-NF-02)
- "Confirm Upgrade" calls `POST /api/billing/upgrade {email}`. The backend calls `charge_card(email, prorated_charge)`; for any email NOT starting with `fail`, it returns `{"status": "success"}`.
- On success: `users[email]["plan"]="Premium"`, `users[email]["price"]="$40/month"`; `billing_data[email]["plan_name"]="Premium"`, `"price"="$40/month"`; `renew_at` unchanged; endpoint returns `{"status":"success","plan":"Premium","charge": <prorated_charge>}`.
- Frontend re-fetches `GET /api/billing`, closes the modal, hides the CTA, shows a success banner ("You're now on Premium! $X.XX was charged.").

**AC-5 — Execute upgrade: card declined & already-Premium guard** (REQ-F-06, REQ-F-08, REQ-F-09, REQ-F-10, REQ-NF-01)
- For any email starting with `fail`, `charge_card` returns `{"status":"card_declined","message":"Your card was declined."}`; the endpoint returns HTTP 402 `{"detail":"card_declined","message":"Your card was declined."}`; no `users`/`billing_data` mutation; the modal stays open showing "Payment failed: Your card was declined. Your plan has not changed."
- `GET /api/billing/upgrade-preview` and `POST /api/billing/upgrade` both return HTTP 409 `{"detail":"already_premium"}` when `billing_data[email]["plan_name"] == "Premium"`; the frontend never renders the CTA for a Premium user (Devraj) in the first place.

**AC-6 — Premium quotas & data** (REQ-F-07)
- On successful upgrade, `billing_data[email]["usages"]` is replaced with Premium values (chat credits 0/10000, chatbots 0/10, document pages 0/5000) and `on_demand_usage.notice` becomes `"On-demand credit is available on your Premium plan."`

### Non-functional constraints on this story
- REQ-NF-03: no changes to `/api/auth/*`, `/api/tasks*`, `/api/users/me`, or `AuthContext.jsx`.
- REQ-NF-05: new endpoints validate input via Pydantic and use the same `{detail, message}` error-shape convention as the rest of `main.py`.

---

## Requirements Coverage Matrix

| REQ-ID | Covering Story | Status |
|---|---|---|
| REQ-F-01 | Story 1 (AC-1) | Covered |
| REQ-F-02 | Story 1 (AC-1) | Covered |
| REQ-F-03 | Story 1 (AC-2) | Covered |
| REQ-F-04 | Story 1 (AC-2) | Covered |
| REQ-F-05 | Story 1 (AC-3) | Covered |
| REQ-F-06 | Story 1 (AC-4, AC-5) | Covered |
| REQ-F-07 | Story 1 (AC-4, AC-6) | Covered |
| REQ-F-08 | Story 1 (AC-5) | Covered |
| REQ-F-09 | Story 1 (AC-4, AC-5) | Covered |
| REQ-F-10 | Story 1 (AC-5) | Covered |
| REQ-NF-01 | Story 1 (AC-4, AC-5) | Covered |
| REQ-NF-02 | Story 1 (AC-4) | Covered |
| REQ-NF-03 | Story 1 (Non-functional constraints) | Covered |
| REQ-NF-04 | Story 1 (AC-2) | Covered |
| REQ-NF-05 | Story 1 (Non-functional constraints) | Covered |

**Result**: 15/15 REQ-IDs fully covered by Story 1's ACs. (Full-coverage check: PASS.)

---

## Story Granularity & Splitting Check (Step 18.6) — VIOLATIONS ACCEPTED BY EXPLICIT USER OVERRIDE

Story 1 fails the Step 1.5 hard sizing ceilings on all four axes:
- **AC count**: 6 ACs (ceiling: 5).
- **Architectural layers**: touches both a new frontend modal/CTA AND two new backend endpoints in one story (ceiling: one newly-touched layer).
- **Scenario classes**: bundles CTA display, happy-path upgrade, card-declined failure, and the already-premium guard — 4 scenario classes (ceiling: 1).
- **Parallelism**: with only 1 story, `team_size: 2` cannot run any of this work in parallel.

These violations are **NOT auto-split**, per the user's explicit instruction after being shown this exact trade-off (see `runtime-artifacts/audit.md`, "User Stories — Story Count Override"). This is recorded here for traceability to any future audit or code review that expects Step 18.6 to have produced zero violations.
