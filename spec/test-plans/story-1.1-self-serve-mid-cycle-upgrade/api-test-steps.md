# API Test Steps — Story 1.1 Self-Serve Mid-Cycle Upgrade: Standard → Premium

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/3157-mid-cycle-subscription-upgrade` |
| This story's merged PR | https://github.com/Shailendrayadav0666/billing-cycle-copy2/pull/7 (merged 2026-09-03T13:45:28Z, commit `b96fbe3`) |
| Confirm the story is in the build | `git log --oneline \| grep -i "self-serve mid-cycle"` |
| How to build & run it | Follow the project's own build docs (`src/README.md`, `src/backend/README.md`). This plan does not restate them. |
| Local base URL / port | Backend: `http://127.0.0.1:8000` |
| Local services that must be up | Backend (uvicorn) dev server only |
| Test data / accounts to seed | Seed user `tpg@example.com` (Standard). Register an additional `fail`-prefixed account for decline-path cases. Use a tool such as `curl` or Postman. |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log functional failures against a system that never started.

---

## Endpoint: `GET /api/billing/upgrade-preview?email=<email>`

### TC-API-01 — Happy path preview for a Standard subscriber

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 / REQ-F-03, REQ-F-04 |
| **Type** | API |
| **Priority** | P1 |
| **Preconditions** | `tpg@example.com` exists and is on Standard |
| **Test data** | `email=tpg@example.com` |

**Steps**
1. `curl "http://127.0.0.1:8000/api/billing/upgrade-preview?email=tpg@example.com"`

**Expected result**
- HTTP 200.
- Response body is JSON with exactly these fields: `current_plan` ("Standard"), `new_plan` ("Premium"), `days_remaining` (positive integer), `prorated_charge` (number, matches the formula `(40-20)/30 × days_remaining`, rounded to 2 decimals), `next_renewal_price` (40.0 or 40), `renew_at` (string, unchanged from `GET /api/billing`).

**Pass/Fail criteria**: PASS only if status is 200, all 6 fields are present with correct types, and `prorated_charge` matches the formula given the account's actual `days_remaining`.
**Cleanup**: None — read-only call.

---

### TC-API-02 — Already-Premium user is guarded (409)

| Field | Value |
|-------|-------|
| **Traces to** | AC-6 / REQ-F-10 |
| **Type** | API |
| **Priority** | P1 |
| **Preconditions** | An account already on Premium |
| **Test data** | Premium account email |

**Steps**
1. `curl -w "\n%{http_code}\n" "http://127.0.0.1:8000/api/billing/upgrade-preview?email=<premium-email>"`

**Expected result**
- HTTP 409.
- Body: `{"detail":"already_premium"}`.

**Pass/Fail criteria**: PASS only if status is exactly 409 with the exact `detail` value.
**Cleanup**: None.

---

### TC-API-03 — Unknown/missing email

| Field | Value |
|-------|-------|
| **Traces to** | ⚠️ TO CONFIRM: neither the epic brief nor the story specifies the expected status/body for an email not present in `billing_data`. This case is included as a boundary probe; the dev team should confirm the intended contract. |
| **Type** | API |
| **Priority** | P3 |
| **Preconditions** | None |
| **Test data** | `email=nonexistent@example.com` and `email=` (empty) |

**Steps**
1. `curl -w "\n%{http_code}\n" "http://127.0.0.1:8000/api/billing/upgrade-preview?email=nonexistent@example.com"`
2. `curl -w "\n%{http_code}\n" "http://127.0.0.1:8000/api/billing/upgrade-preview?email="`
3. `curl -w "\n%{http_code}\n" "http://127.0.0.1:8000/api/billing/upgrade-preview"` (no `email` param at all)

**Expected result**
- A deterministic, non-500 response for all three (exact status/body ⚠️ TO CONFIRM — record what is actually observed as the baseline contract if undocumented).

**Pass/Fail criteria**: FAIL only if the server returns an unhandled HTTP 500 / stack trace for any of the three.
**Cleanup**: None.

---

## Endpoint: `POST /api/billing/upgrade`

### TC-API-04 — Happy path upgrade (success)

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 / REQ-F-06, REQ-F-07 |
| **Type** | API |
| **Priority** | P1 |
| **Preconditions** | A fresh Standard account (not previously upgraded), email does NOT start with `fail` |
| **Test data** | `{"email":"tpg@example.com"}` |

**Steps**
1. `curl -X POST -H "Content-Type: application/json" -d '{"email":"tpg@example.com"}' "http://127.0.0.1:8000/api/billing/upgrade"`

**Expected result**
- HTTP 200.
- Body: `{"status":"success","plan":"Premium","charge":<number matching the preview's prorated_charge>}`.
- A follow-up `GET /api/billing?email=tpg@example.com` shows plan Premium, price $40/month, updated quotas (10000/10/5000), and the on-demand notice text changed.

**Pass/Fail criteria**: PASS only if the response matches exactly and the follow-up GET confirms the full state change.
**Cleanup**: Restart the backend process.

---

### TC-API-05 — Declined payment (fail-prefixed email)

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 (failure path) / REQ-F-08, REQ-NF-01 |
| **Type** | API |
| **Priority** | P1 |
| **Preconditions** | A Standard account whose email starts with `fail` |
| **Test data** | `{"email":"fail-tester@example.com"}` |

**Steps**
1. `curl -w "\n%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{"email":"fail-tester@example.com"}' "http://127.0.0.1:8000/api/billing/upgrade"`
2. Immediately `GET /api/billing?email=fail-tester@example.com`.

**Expected result**
- Step 1: HTTP 402, body `{"detail":"card_declined","message":"Your card was declined."}` (message text may vary slightly, but must clearly state the card was declined).
- Step 2: response identical to the pre-attempt state — plan still Standard, no quota changes.

**Pass/Fail criteria**: PASS only if status is exactly 402 and step 2 confirms zero mutation.
**Cleanup**: None — no state changed.

---

### TC-API-06 — Determinism of the dummy gateway

| Field | Value |
|-------|-------|
| **Traces to** | REQ-NF-01 |
| **Type** | API |
| **Priority** | P2 |
| **Preconditions** | Two fresh accounts: one `fail`-prefixed, one not |
| **Test data** | Both accounts |

**Steps**
1. Call `POST /api/billing/upgrade` for the non-`fail` account 3 times in a row (restarting the backend between each call to reset state, or using 3 different non-`fail` test accounts).
2. Call `POST /api/billing/upgrade` for a `fail`-prefixed account 3 times in a row (3 different `fail`-prefixed accounts, since a declined call makes no mutation to retry against).

**Expected result**
- All 3 non-`fail` calls return `{"status":"success", ...}`.
- All 3 `fail`-prefixed calls return HTTP 402 `card_declined`.
- No call ever returns a third outcome, and no call's result depends on retry count or timing.

**Pass/Fail criteria**: PASS only if the outcome is 100% consistent with the email prefix across all 6 calls.
**Cleanup**: Restart the backend process.

---

### TC-API-07 — Already-Premium guard on the upgrade endpoint (409)

| Field | Value |
|-------|-------|
| **Traces to** | AC-6 / REQ-F-10 |
| **Type** | API |
| **Priority** | P1 |
| **Preconditions** | An account already on Premium |
| **Test data** | Premium account email |

**Steps**
1. `curl -w "\n%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{"email":"<premium-email>"}' "http://127.0.0.1:8000/api/billing/upgrade"`

**Expected result**
- HTTP 409, body `{"detail":"already_premium"}`.

**Pass/Fail criteria**: PASS only if status is exactly 409 with the exact `detail` value.
**Cleanup**: None.

---

### TC-API-08 — Bad payload validation

| Field | Value |
|-------|-------|
| **Traces to** | REQ-NF-04 (stays within existing conventions — FastAPI/Pydantic validation) |
| **Type** | API |
| **Priority** | P2 |
| **Preconditions** | None |
| **Test data** | Missing `email` field; `email` as a non-string (e.g. `123`); empty JSON body `{}`; malformed JSON |

**Steps**
1. `curl -w "\n%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{}' "http://127.0.0.1:8000/api/billing/upgrade"`
2. `curl -w "\n%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{"email":123}' "http://127.0.0.1:8000/api/billing/upgrade"`
3. `curl -w "\n%{http_code}\n" -X POST -H "Content-Type: application/json" -d 'not-json' "http://127.0.0.1:8000/api/billing/upgrade"`

**Expected result**
- All three return HTTP 422 (FastAPI's standard validation-error status) with a structured error body — never a 500.

**Pass/Fail criteria**: FAIL if any case returns a 500 or an unhandled exception/stack trace.
**Cleanup**: None.

---

## Coverage
- AC-2 → TC-API-01
- AC-6 → TC-API-02, TC-API-07
- AC-4 → TC-API-04, TC-API-05
- REQ-NF-01 → TC-API-06
- Non-AC boundary/robustness → TC-API-03, TC-API-08
