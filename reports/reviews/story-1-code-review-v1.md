# Code Review — Story 1: Mid-Cycle Subscription Upgrade (Standard → Premium)

**Reviewer**: Automated Code Review (AIRE, read-only)
**Scope**: `src/backend/main.py`, `src/frontend/src/pages/Billing.jsx`, `src/frontend/src/App.css`
**Reference**: `spec/plans/stories.md` (Story 1, AC-1..AC-6), `spec/plans/requirements.md` (REQ-F-01..10, REQ-NF-01..05), `spec/plans/architecture.md` Section 10

## Acceptance Criteria Verification

| AC | Requirement | Verified by | Result |
|---|---|---|---|
| AC-1 | CTA shown only for Standard; dynamic plan badge | `Billing.jsx` conditional render (`data.plan_name === 'Standard'`); badge now reads `{data.plan_name}` (line ~226), hardcoded string removed | Met |
| AC-2 | Server-side proration preview | `_compute_prorated_charge`, `GET /api/billing/upgrade-preview`; `test_upgrade_preview_computes_exact_proration_from_epic_example` | Met |
| AC-3 | Confirm/Cancel; Cancel is a no-op | `closeUpgradeModal` makes no fetch call; Cancel button wired to it | Met |
| AC-4 | Happy-path execution | `POST /api/billing/upgrade` success branch; `test_upgrade_success_flips_plan_and_quotas`, `test_billing_endpoint_reflects_premium_after_upgrade` | Met |
| AC-5 | Decline path + already-Premium guard | `test_upgrade_declined_leaves_plan_unchanged`, `test_preview_rejects_already_premium`, `test_upgrade_rejects_already_premium_before_charging` | Met |
| AC-6 | Premium quotas & on-demand notice | `PREMIUM_USAGES`/`PREMIUM_ON_DEMAND_NOTICE` applied in the upgrade handler; asserted in `test_upgrade_success_flips_plan_and_quotas` | Met |

**Verdict: All 6 ACs Met.**

## Test Evidence (cited, not re-run — see `reports/unit-test-evidence/story-1/` and `reports/api-contract-test-evidence/story-1/`)
- 10/10 unit tests passing, 100% coverage on all changed code (`unit-test-run.log`, `coverage-report.xml`).
- API & Contract checklist: functional, response-code, error-response, request validation, response-schema all PASS on both new endpoints; role-based-authorization rows N/A (no role model exists anywhere in this codebase).

## Security Baseline Review (Phase 2.5, diff-scoped)

Checked the 16 Security Baseline rules against the changed surface (`main.py` new endpoints, `charge_card`, `Billing.jsx`):

- **Input validation**: both endpoints validate via Pydantic (`UpgradeRequest`) / FastAPI query typing, consistent with existing handlers. No raw string interpolation into any query/command.
- **Access control**: reuses the existing `email in users` check; no new authorization model introduced (matches existing system-wide pattern — not a regression).
- **Error handling**: no stack traces or internals leaked; error shapes (`{detail, message}` / `{detail}`) match existing conventions.
- **Secrets/PII in logs**: no new logging statements added; no secrets/PII embedded in code.
- **SSRF / file uploads / XML / CSRF / JWT / network config / credential management / session integrity / supply chain / alerting**: not applicable — this story adds no network calls, file handling, XML parsing, cross-site form actions, tokens, or new infrastructure.

**No 🔴 Critical or 🟠 High findings.**

## Architecture Conformance (J1) & OWASP Security (J2)

See `reports/eval-evidence/story-1/judge/architecture-score.json` (1.00) and `security-score.json` (1.00) — both above the `llmJudgeArchitectureScoreMin`/`llmJudgeSecurityScoreMin` (0.85) thresholds.

## Findings

**None.** Zero 🔴 Blocker, zero 🟠 High findings.

## Advisory (non-blocking, informational only)
- 🔵 `spec/behavior/story-1.feature` was authored but its Gherkin step definitions and the Podman-sandboxed B1/B2/B3 execution were not run in this pass (recorded as `DEFERRED` in `eval-summary.md`, not claimed as a pass). Recommend running this before considering the story fully verified end-to-end, or via `/ve-implement` for the manual test-plan equivalent.
- 🔵 D3 (SAST/semgrep) and D7 (secrets/gitleaks) ran as manual review rather than the automated tool, since neither tool is installed in this environment. No findings either way; recommend installing both for future cycles.

## Verdict

**CLEAN** — all ACs Met, zero blocking findings, both judge gates PASS. Proceeding to commit, push, and raise the PR.
