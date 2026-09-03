# Security Test Steps — Story 1.1 Self-Serve Mid-Cycle Upgrade: Standard → Premium

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/3157-mid-cycle-subscription-upgrade` |
| This story's merged PR | https://github.com/Shailendrayadav0666/billing-cycle-copy2/pull/7 (merged 2026-09-03T13:45:28Z, commit `b96fbe3`) |
| Confirm the story is in the build | `git log --oneline \| grep -i "self-serve mid-cycle"` |
| How to build & run it | Follow the project's own build docs (`src/README.md`, `src/backend/README.md`). This plan does not restate them. |
| Local base URL / port | Backend: `http://127.0.0.1:8000` |
| Local services that must be up | Backend (uvicorn) dev server only |
| Test data / accounts to seed | Two accounts: `tpg@example.com` (Standard) and a second freshly-registered account belonging to a different "identity" for the IDOR-style check below |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log functional failures against a system that never started.

---

### TC-SEC-01 — Cross-account billing access (IDOR-style check)

| Field | Value |
|-------|-------|
| **Traces to** | REQ-NF-04 (stays within the existing auth pattern) |
| **Type** | Security |
| **Priority** | P1 |
| **Preconditions** | Two distinct registered accounts, both on Standard |
| **Test data** | Account A's credentials, Account B's email |

**Steps**
1. Log in as Account A in the browser (or capture Account A's own `token`/email as used by the app's existing auth pattern).
2. While authenticated as Account A, call `GET /api/billing/upgrade-preview?email=<Account B's email>` and `POST /api/billing/upgrade {"email": "<Account B's email>"}` — i.e. attempt to preview/execute an upgrade for a DIFFERENT account than the one currently authenticated.

**Expected result**
- ⚠️ TO CONFIRM: the epic/requirements documents describe the endpoints as taking `email` as an identity parameter, mirroring the existing `GET /api/billing` pattern (which the epic states already works this way) — but do not explicitly state whether the backend cross-checks `email` against the authenticated caller. This test records the ACTUAL observed behavior as the baseline. If Account A can preview/mutate Account B's billing state, flag it via `/raise-defect` referencing this test case — the reviewed architecture (`ARCH-04`/Security rubric `SEC-01` in `tests/.evals/rubrics/security-rubric.json`) expects the caller's own identity to gate access.

**Pass/Fail criteria**: PASS only if the app's own existing identity convention is upheld to the same degree as `GET /api/billing` already does (i.e. this story does not weaken that pattern further). Record findings either way.
**Cleanup**: Restart the backend process if any mutation occurred against Account B.

---

### TC-SEC-02 — Already-Premium guard cannot be bypassed to re-charge

| Field | Value |
|-------|-------|
| **Traces to** | AC-6 / REQ-F-10 |
| **Type** | Security |
| **Priority** | P1 |
| **Preconditions** | An account already on Premium |
| **Test data** | Premium account email |

**Steps**
1. Rapidly issue 5 concurrent `POST /api/billing/upgrade` requests for the same already-Premium account (e.g. using `curl` in a loop with `&` to background them, or a tool like `ab`/`hey`).

**Expected result**
- Every request returns HTTP 409 `already_premium`. No request is charged again, no quota is doubled.

**Pass/Fail criteria**: FAIL if any of the 5 concurrent requests returns 200/success.
**Cleanup**: None expected — but re-verify billing state afterward via `GET /api/billing`.

---

### TC-SEC-03 — No sensitive data leaked in responses

| Field | Value |
|-------|-------|
| **Traces to** | REQ-NF-04 |
| **Type** | Security |
| **Priority** | P2 |
| **Preconditions** | None |
| **Test data** | Any account |

**Steps**
1. Inspect the full response bodies of `GET /api/billing/upgrade-preview` and `POST /api/billing/upgrade` (both success and 402/409 paths) for the password field, any internal user ID beyond what the existing `GET /api/billing` already exposes, or any stack trace / internal file path.

**Expected result**
- No password, internal secret, or stack trace appears in any response body across all paths tested.

**Pass/Fail criteria**: FAIL if any sensitive field or stack trace is present.
**Cleanup**: None.

---

### TC-SEC-04 — Injection-style input on the `email` field

| Field | Value |
|-------|-------|
| **Traces to** | Security Baseline — input validation |
| **Type** | Security |
| **Priority** | P2 |
| **Preconditions** | None |
| **Test data** | `email` values: `"; DROP TABLE users; --"`, `"<script>alert(1)</script>"`, a very long string (10,000+ chars) |

**Steps**
1. `curl -X POST -H "Content-Type: application/json" -d '{"email":"<script>alert(1)</script>"}' "http://127.0.0.1:8000/api/billing/upgrade"`
2. Repeat with the SQL-injection-style string and the oversized string, for both endpoints.

**Expected result**
- No 500 error, no unhandled exception. Since there is no real database (in-memory dict), an injection string is simply treated as an unmatched email — expect the same behavior as TC-API-03 (unknown email), never a crash.

**Pass/Fail criteria**: FAIL on any 500/crash or on any sign the string was executed/interpreted rather than treated as opaque data.
**Cleanup**: None.

---

## Coverage
- REQ-NF-04 → TC-SEC-01, TC-SEC-03
- AC-6 / REQ-F-10 → TC-SEC-02
- Security Baseline (input validation) → TC-SEC-04
