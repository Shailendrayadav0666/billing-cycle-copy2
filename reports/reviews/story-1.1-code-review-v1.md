# Code Review — Story 1.1 — Self-Serve Mid-Cycle Upgrade: Standard → Premium (v1)

**Scope**: Story 1.1 only. Read-only review.
**Covers**: REQ-F-01..11, REQ-NF-01..05 (spec/plans/requirements.md via stories.md Covers line)

## Acceptance Criteria verification

| AC | Requirement(s) | Verdict | Evidence |
|---|---|---|---|
| AC-1 | REQ-F-01, REQ-F-02 | ✅ Met | `Billing.jsx` badge now renders `data.plan_name` (was hardcoded "Standard"); CTA gated on `data.plan_name === 'Standard'`. Behavior scenarios: 2 (@AC-1). |
| AC-2 | REQ-F-03, REQ-F-04 | ✅ Met | `GET /api/billing/upgrade-preview` computes proration entirely server-side (`_calculate_proration`, `main.py:221`); modal fetches and displays it, no client math. Unit tests: `test_upgrade_preview_returns_prorated_charge`, `test_proration_formula_matches_epic_example`. |
| AC-3 | REQ-F-05 | ✅ Met | `closeUpgradeModal` resets state with zero backend calls; `Cancel` button wired to it. Behavior scenario @AC-3. |
| AC-4 | REQ-F-06, REQ-F-07, REQ-NF-01, REQ-NF-02 | ✅ Met | `charge_card` deterministic on email prefix; success path atomically updates `users`, `billing_data` plan/price/quotas/notice (`main.py:264-278`). Unit tests: `test_successful_upgrade_response_body`, `test_successful_upgrade_flips_users_and_billing_plan`, `test_successful_upgrade_sets_premium_quota_totals`. Frontend re-fetches billing and shows a success banner. |
| AC-5 | REQ-F-08, REQ-F-09, REQ-NF-02 | ✅ Met | Guard clause returns 402 with `{"detail":"card_declined","message":...}` BEFORE any mutation (`main.py:270-274`); `test_declined_upgrade_mutates_nothing` asserts byte-for-byte equality of `users`/`billing_data` before/after. Modal shows inline error, stays open. |
| AC-6 | REQ-F-10 | ✅ Met | Already-Premium guard is the first statement in both endpoints, returns 409 `{"detail":"already_premium"}` before any other logic. `test_preview_already_premium_returns_409`, `test_upgrade_already_premium_returns_409_and_no_mutation`. |
| AC-7 | REQ-F-11, REQ-NF-03, REQ-NF-04 | ✅ Met | `renew_at` never assigned in the upgrade path (`test_successful_upgrade_preserves_renew_at`, `test_renew_at_unchanged` behavior scenario). `git diff` confirms zero changes to `requirements.txt`/`package.json`, and zero touch to `/api/auth/*`, `/api/tasks`, `/api/users/me`. |

**Requirements coverage**: 16/16 REQ-IDs (11 functional + 5 non-functional) verified against the code, not just the AC restatement — matches `spec/plans/requirements.md`.

## Test evidence (captured by the gates, not re-run here)

- Unit + coverage: `reports/unit-test-evidence/story-1.1/` — 40/40 tests pass, 100% coverage on new/changed lines. See `unit-test-run.log`, `coverage-report.xml`, `full-regression.log` (baseline 2 passed → 40 passed, 0 new failures).
- API & Contract: `reports/api-contract-test-evidence/story-1.1/` — full checklist PASS (role-based-authorization N/A, no role model in this app).
- Behavior: `reports/behavior-test-evidence/story-1.1/` — B1 9/9 (7/7 AC tags), B2 N/A (no other feature file), B3 N/A (empty cross-story feature file by design).
- Static evals: `reports/eval-evidence/story-1.1/` — D1-D7 clean vs baseline (see `eval.json`/`eval-summary.md`).

## Architecture conformance (J1) — score 1.00 ≥ 0.85

All 5 `architecture.md` Section 10 constraints verified directly against the diff:
- ARCH-01 (server-side-only proration): no proration arithmetic in `Billing.jsx` — confirmed by reading the diff.
- ARCH-02 (deterministic gateway): `charge_card` has no randomness/network/clock call.
- ARCH-03 (no partial mutation on failure): guard-then-mutate ordering verified line-by-line.
- ARCH-04 (already-Premium guard first): confirmed as the first statement in both endpoints.
- ARCH-05 (no new dependencies): `requirements.txt`/`package.json` diffs are empty.

## Security (J2 + Phase 2.5 Security Baseline) — score 0.95 ≥ 0.85

See `reports/code-security-reviews/security-review-2026-09-03.md`. One 🟡 advisory finding (SEC-01, broken access control, matches pre-existing app convention) — **not blocking**, no 🔴/🟠 findings.

## Verdict

**CLEAN** — all 7 ACs Met, 0 🔴 Blocker, 0 🟠 High findings, J1 = 1.00, J2 = 0.95. Proceeding to commit + PR.
