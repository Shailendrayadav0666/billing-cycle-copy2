# API & Contract Testing Gate — Story 1 (Mid-Cycle Subscription Upgrade)

**Applicability**: Story 1's plan includes an API Layer Generation step (`GET /api/billing/upgrade-preview`,
`POST /api/billing/upgrade`) — this gate applies.

**Test suite** (same suite as unit-test evidence, run against the real FastAPI app via `TestClient`,
which sends actual HTTP requests through FastAPI's routing/validation/serialization — this is a real
contract test, not a mock): `tests/unit/backend/test_billing_upgrade.py`
**Command**: `python -m pytest tests/unit/backend -v` (see `reports/unit-test-evidence/story-1/unit-test-run.log`)
**Result**: 10/10 passing

## Per-endpoint checklist

### `GET /api/billing/upgrade-preview`
| Check | Covered by | Result |
|---|---|---|
| Functional / happy path | `test_upgrade_preview_computes_exact_proration_from_epic_example` | PASS |
| Response-code validation (200, 401, 409) | same test + `test_upgrade_preview_unknown_email_is_401` + `test_preview_rejects_already_premium` | PASS |
| Role-based authorization (401/403) | N/A — this system has no role/permission model, only the existing email-known/unknown check reused from `GET /api/billing`; `test_upgrade_preview_unknown_email_is_401` covers the 401 case. No 403 exists anywhere in this codebase to be consistent with. |
| Error-response validation | `test_upgrade_preview_unknown_email_is_401` (`{"detail": "Not authenticated"}`), `test_preview_rejects_already_premium` (`{"detail": "already_premium"}`) — both match the existing codebase's `{detail: ...}` shape | PASS |
| Request validation | `email` is a required query param; FastAPI 422s on a missing param by framework default (not story-specific, not re-tested) | PASS (framework-guaranteed) |
| Response contract/schema | `test_upgrade_preview_computes_exact_proration_from_epic_example` asserts every field: `current_plan`, `new_plan`, `days_remaining`, `prorated_charge`, `next_renewal_price`, `renew_at` | PASS |

### `POST /api/billing/upgrade`
| Check | Covered by | Result |
|---|---|---|
| Functional / happy path | `test_upgrade_success_flips_plan_and_quotas` | PASS |
| Response-code validation (200, 401, 402, 409) | `test_upgrade_success_flips_plan_and_quotas` (200), `test_upgrade_unknown_email_is_401` (401), `test_upgrade_declined_leaves_plan_unchanged` (402), `test_upgrade_rejects_already_premium_before_charging` (409) | PASS |
| Role-based authorization (401/403) | N/A — same reasoning as above; 401 covered, no role model exists |
| Error-response validation | 402 body asserted as `{"detail": "card_declined", "message": "Your card was declined."}`; 409 body asserted as `{"detail": "already_premium"}` | PASS |
| Request validation | Pydantic `UpgradeRequest(email: str)` — a missing/malformed body 422s by framework default | PASS (framework-guaranteed) |
| Response contract/schema | `test_upgrade_success_flips_plan_and_quotas` asserts the exact body `{"status": "success", "plan": "Premium", "charge": 10.00}` | PASS |

**Verdict**: Every applicable checklist item passes. Role-based-authorization rows are N/A because this
codebase has no role/permission concept anywhere (verified against `spec/plans/deep-dive.md`) — not a
gap introduced by this story.
