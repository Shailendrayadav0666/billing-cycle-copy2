# Integration Test Steps — Story 1.1 Self-Serve Mid-Cycle Upgrade: Standard → Premium

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/3157-mid-cycle-subscription-upgrade` |
| This story's merged PR | https://github.com/Shailendrayadav0666/billing-cycle-copy2/pull/7 (merged 2026-09-03T13:45:28Z, commit `b96fbe3`) |
| Confirm the story is in the build | `git log --oneline \| grep -i "self-serve mid-cycle"` |
| How to build & run it | Follow the project's own build docs (`src/README.md`, `src/backend/README.md`, `src/frontend/README.md`). This plan does not restate them. |
| Local base URL / port | Backend: `http://127.0.0.1:8000` · Frontend: `http://localhost:5173` (Vite dev server proxies `/api` to `:8000`) |
| Local services that must be up | Backend (uvicorn) and frontend (vite dev) dev servers only — no database, no external services |
| Test data / accounts to seed | Seed user `tpg@example.com` / `password` (Standard plan, pre-loaded). Register one additional account with an email starting with `fail` (e.g. `fail-tester@example.com`) via the Register page or `POST /api/auth/register`, to exercise the declined-payment path. |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log functional failures against a system that never started.

---

### TC-INT-01 — Upgrade mutation is observable across the frontend/backend boundary

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 / REQ-F-07, REQ-NF-02 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | System Under Test running; logged in as `tpg@example.com` (Standard) |
| **Test data** | `tpg@example.com` |

**Steps**
1. Call `GET /api/billing?email=tpg@example.com` directly (e.g. via curl or browser devtools) and note the response: `plan_name`, `price`, `usages` totals.
2. On the Billing page, click **Upgrade to Premium**, then **Confirm Upgrade**.
3. Immediately re-call `GET /api/billing?email=tpg@example.com` (a fresh request, not the cached page state).

**Expected result**
- Step 3's response shows `plan_name: "Premium"`, `price: "$40/month"`, and `usages` totals updated (chat credits 10000, chatbots 10, document pages 5000) — i.e. the POST's effect on the backend is independently observable via a separate GET call, not just reflected in the UI's own local state.

**Pass/Fail criteria**: PASS only if the independent GET call (not the page's own re-render) reflects the new plan and quotas. FAIL if the backend state is unchanged or only partially updated.
**Cleanup**: Restart the backend process (in-memory store resets) before the next test case that needs a Standard user.

---

### TC-INT-02 — Declined payment produces zero backend-side mutation

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 / REQ-F-08, REQ-NF-02 |
| **Type** | Integration |
| **Priority** | P1 |
| **Preconditions** | System Under Test running; a registered account with email starting `fail` (Standard plan) |
| **Test data** | `fail-tester@example.com` |

**Steps**
1. Call `GET /api/billing?email=fail-tester@example.com` directly and note the full response body.
2. On the Billing page (or via `POST /api/billing/upgrade` directly), attempt the upgrade for this account.
3. Re-call `GET /api/billing?email=fail-tester@example.com` directly.

**Expected result**
- The upgrade attempt returns HTTP 402 with `{"detail":"card_declined", ...}`.
- Step 3's response is **byte-for-byte identical** to step 1's — plan, price, quotas, `renew_at` all unchanged.

**Pass/Fail criteria**: PASS only if the two GET responses are identical. FAIL on any difference, however small (e.g. a quota counter incremented, a notice string changed).
**Cleanup**: None required — no state changed.

---

### TC-INT-03 — `renew_at` is preserved unchanged across the boundary after a successful upgrade

| Field | Value |
|-------|-------|
| **Traces to** | AC-5 (epic-level AC "renew_at date is preserved unchanged") / REQ-F-09 |
| **Type** | Integration |
| **Priority** | P2 |
| **Preconditions** | System Under Test running; a Standard user |
| **Test data** | `tpg@example.com` |

**Steps**
1. `GET /api/billing?email=tpg@example.com`, record the `renew_at` value.
2. Perform a successful upgrade (CTA → Confirm Upgrade).
3. `GET /api/billing?email=tpg@example.com` again, record `renew_at`.

**Expected result**
- `renew_at` in step 3 is identical to step 1 — the upgrade does not shift the renewal date.

**Pass/Fail criteria**: PASS only if the two `renew_at` values match exactly.
**Cleanup**: Restart the backend process.

---

## Coverage
- AC-4 → TC-INT-01
- AC-5 → TC-INT-02, TC-INT-03
