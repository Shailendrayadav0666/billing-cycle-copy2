# E2E Test Steps — Story 1.1 Self-Serve Mid-Cycle Upgrade: Standard → Premium

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/3157-mid-cycle-subscription-upgrade` |
| This story's merged PR | https://github.com/Shailendrayadav0666/billing-cycle-copy2/pull/7 (merged 2026-09-03T13:45:28Z, commit `b96fbe3`) |
| Confirm the story is in the build | `git log --oneline \| grep -i "self-serve mid-cycle"` |
| How to build & run it | Follow the project's own build docs (`src/README.md`, `src/backend/README.md`, `src/frontend/README.md`). This plan does not restate them. |
| Local base URL / port | Backend: `http://127.0.0.1:8000` · Frontend: `http://localhost:5173` |
| Local services that must be up | Backend (uvicorn) and frontend (vite dev) dev servers only |
| Test data / accounts to seed | Seed user `tpg@example.com` / `password` (Standard). Register a second account with an email starting `fail` for the decline journey. |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log functional failures against a system that never started.

---

### TC-E2E-01 — Happy path: Standard subscriber completes the upgrade

| Field | Value |
|-------|-------|
| **Traces to** | AC-1, AC-2, AC-3, AC-4 |
| **Type** | E2E |
| **Priority** | P1 |
| **Preconditions** | Logged in as a Standard subscriber |
| **Test data** | `tpg@example.com` / `password` |

**Steps**
1. Log in and navigate to the Billing page.
2. Confirm the plan card shows "Standard" and an **Upgrade to Premium** button is visible.
3. Click **Upgrade to Premium**.
4. In the confirmation modal, verify it shows: current plan Standard ($20/mo), new plan Premium ($40/mo), days remaining, a prorated charge amount, and the next renewal price/date.
5. Click **Confirm Upgrade**.
6. Observe the page after the call completes.

**Expected result**
- Modal closes; a success banner reading something like "You're now on Premium! $X.XX was charged." appears.
- The plan card now shows Premium, price $40/month, "Active" badge.
- The usage section shows updated quotas (10,000 chat credits / 10 chatbots / 5,000 document pages).
- The **Upgrade to Premium** button is no longer present anywhere on the page.

**Pass/Fail criteria**: PASS only if all of the above are true after step 6 without a page reload. FAIL if the button is still visible, the banner is missing, or any quota/plan value is stale.
**Cleanup**: Restart the backend process to reset the in-memory store to Standard.

---

### TC-E2E-02 — Cancel path: modal closes with no side effects

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 (Cancel action) |
| **Type** | E2E |
| **Priority** | P2 |
| **Preconditions** | Logged in as a Standard subscriber |
| **Test data** | `tpg@example.com` |

**Steps**
1. Navigate to Billing, click **Upgrade to Premium**.
2. Wait for the preview to load in the modal.
3. Click **Cancel**.
4. Reload the Billing page.

**Expected result**
- Modal closes immediately on Cancel with no network request to the upgrade endpoint (verify via browser devtools Network tab — only the preview `GET` should have fired, never a `POST /api/billing/upgrade`).
- After reload, plan is still Standard, **Upgrade to Premium** button is still present, all values unchanged from before the attempt.

**Pass/Fail criteria**: PASS only if no `POST /api/billing/upgrade` request appears in the Network tab and the plan is unchanged.
**Cleanup**: None required.

---

### TC-E2E-03 — Decline path: failed payment leaves the user on Standard with an inline error

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 (failure path) / epic AC "Confirming with a fail* email fails" |
| **Type** | E2E |
| **Priority** | P1 |
| **Preconditions** | Logged in as an account whose email starts with `fail` |
| **Test data** | `fail-tester@example.com` |

**Steps**
1. Register and log in as `fail-tester@example.com` (Standard plan by default).
2. Navigate to Billing, click **Upgrade to Premium**, wait for the preview.
3. Click **Confirm Upgrade**.

**Expected result**
- The modal stays open and shows an inline error: "Payment failed: Your card was declined. Your plan has not changed." (or equivalent wording carrying the same information).
- No success banner appears.
- The plan card behind the modal (once closed via Cancel) still shows Standard.

**Pass/Fail criteria**: PASS only if the modal remains open with the error visible and the user is never shown a success state. FAIL if the modal closes on decline or the plan silently changes.
**Cleanup**: None required — no state changed on the backend.

---

### TC-E2E-04 — Already-Premium user never sees the CTA

| Field | Value |
|-------|-------|
| **Traces to** | AC-6 |
| **Type** | E2E |
| **Priority** | P1 |
| **Preconditions** | An account already on Premium (e.g. run TC-E2E-01 first, or manually set up a Premium account if the seed data supports it) |
| **Test data** | `tpg@example.com` (after TC-E2E-01) |

**Steps**
1. Log in as the now-Premium user.
2. Load the Billing page.
3. Visually inspect the entire page (including scrolling) for any upgrade-related CTA.

**Expected result**
- No **Upgrade to Premium** button, link, or any other upgrade prompt is rendered anywhere on the page.

**Pass/Fail criteria**: PASS only if no upgrade CTA is present. FAIL if any upgrade-prompting element is visible.
**Cleanup**: Restart the backend process to reset state for subsequent runs.

---

### TC-E2E-05 — Unrelated flows (login, registration, tasks) are unaffected

| Field | Value |
|-------|-------|
| **Traces to** | AC-7 |
| **Type** | E2E |
| **Priority** | P2 |
| **Preconditions** | None |
| **Test data** | A new email/password for registration; `tpg@example.com` / `password` for login |

**Steps**
1. Register a brand-new account through the Register page.
2. Log out, then log back in with that account's credentials.
3. Navigate to the Tasks page (or equivalent) and create/view a task if the app supports it.
4. Log in as `tpg@example.com` and confirm the existing login flow still works unchanged.

**Expected result**
- Registration, login, and the tasks flow all behave exactly as before this story — no new fields, no new prompts, no errors introduced by the billing-upgrade changes.

**Pass/Fail criteria**: FAIL if registration, login, or tasks show any new behavior, error, or regression traceable to this story's changes.
**Cleanup**: None required.

---

## Coverage
- AC-1, AC-2, AC-3, AC-4 → TC-E2E-01
- AC-2 → TC-E2E-02
- AC-4 → TC-E2E-03
- AC-6 → TC-E2E-04
- AC-7 → TC-E2E-05
