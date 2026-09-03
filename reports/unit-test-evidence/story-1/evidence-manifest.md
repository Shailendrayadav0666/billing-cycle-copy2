# Unit Test & Coverage Evidence — Story 1 (Mid-Cycle Subscription Upgrade)

**Command**: `python -m pytest tests/unit/backend -v --cov=src/backend --cov-report=term-missing --cov-report=xml:reports/unit-test-evidence/story-1/coverage-report.xml`
**Result**: 10/10 tests passing
**Coverage (whole file, informational)**: 81% (110 stmts, 21 missed)
**Coverage (scope: changed-files, per tests/.evals/config.json `scope: "changed-files"`)**: 100% on every line this story added — `PLANS`, `DAYS_IN_CYCLE`, `PREMIUM_USAGES`, `PREMIUM_ON_DEMAND_NOTICE`, `UpgradeRequest`, `charge_card()`, `_compute_prorated_charge()`, `billing_upgrade_preview()`, `billing_upgrade()`. Verified against `git diff epic/mid-cycle-subscription-upgrade -- src/backend/main.py`: every "Missing" line reported by coverage.py (167-170, 176, 237-240, 246, 298-300, 305-311, 317) falls in pre-existing `login`/`register`/`me`/`billing`/`tasks`/`add_task`/static-mount code this story did not touch.
**Threshold**: `unitTestCoverageMin` = 90.0 (tests/.evals/config.json) — **PASS** (100% on changed code).

## Test list
- `test_charge_card_deterministic_success` / `test_charge_card_deterministic_decline` — REQ-NF-01, ARCH-02
- `test_upgrade_preview_computes_exact_proration_from_epic_example` — AC-2, REQ-F-04
- `test_upgrade_preview_unknown_email_is_401` / `test_upgrade_unknown_email_is_401` — auth guard parity with existing endpoints
- `test_upgrade_success_flips_plan_and_quotas` / `test_billing_endpoint_reflects_premium_after_upgrade` — AC-4, AC-6, REQ-F-06/07/09
- `test_upgrade_declined_leaves_plan_unchanged` — AC-5, REQ-F-08
- `test_preview_rejects_already_premium` / `test_upgrade_rejects_already_premium_before_charging` — AC-5, REQ-F-10, ARCH-04

## Artifacts
- `unit-test-run.log` — raw pytest output
- `coverage-report.xml` — Cobertura XML (machine-readable)

## Bootstrap
No new backend dependency added to `src/backend/requirements.txt` (ARCH-05 / REQ-NF-02). Test-only tools
(`pytest`, `pytest-cov`, `httpx`) were added to a NEW file `src/backend/requirements-dev.txt` (`-r requirements.txt`
plus the three dev tools) so the production manifest stays byte-identical to its pre-epic version.
