### Eval Scorecard — Story 1.1 · **PASS**

| Gate | Result | Threshold | Status |
|---|---|---|---|
| D1 Lint | 0 new findings | ≤ 0 delta | ✅ PASS |
| D2 Type check | 0 new errors (2 pre-existing baseline errors unchanged) | 0 | ✅ PASS |
| D3 Static security | 0C / 0H / 0M (semgrep p/security-audit, 79 rules) | 0C / 0H / ≤5M | ✅ PASS |
| D4 Dependencies | no dependency changed | N/A | ⚪ N/A |
| D5 Licences | no dependency changed | N/A | ⚪ N/A |
| D6 Complexity | max 6 | ≤ 12 | ✅ PASS |
| D7 Secrets | 0 findings | 0 | ✅ PASS |
| Unit coverage | 100% on new/changed lines | ≥ 90.0% | ✅ PASS |
| Behavioural B1 (this story) | 9/9 scenarios · 7/7 ACs · not containerised (Podman VM failed to start in this sandbox) | 100% | ✅ PASS (unverified container parity) |
| Behavioural B2 (cumulative) | no other feature file exists | — | ⚪ N/A |
| Behavioural B3 (epic scope) | spec/behavior.feature has zero scenarios by design | — | ⚪ N/A |
| API & contract | 2/2 endpoints, full checklist (role-based auth N/A — no role model) | all applicable | ✅ PASS |
| Regression | 0 new failures (baseline 2 passed → 40 passed) | 0 | ✅ PASS |
| J1 Architecture | 1.00 | ≥ 0.85 | ✅ PASS |
| J2 Security (OWASP 2025) | 0.95 | ≥ 0.85 | ✅ PASS |

**Verdict**: PASS · judge `claude-sonnet-5` · rubric v1.0.0 (from `architecture.md` v1.0.0)
**Self-healing**: SH-LOOP-1 1/3 (test assertion fix for a wall-clock truncation artifact) · SH-LOOP-4 1/3 (bootstrapped src/backend/ruff.toml + type-annotated 3 module dicts to resolve mypy false positives) · all other loops 0/3

**Advisory (non-blocking) finding**: SEC-01 (A01:2025 Broken Access Control) scored 0.9 — the two new endpoints trust the caller-supplied `email` with no stronger verification than the pre-existing `GET /api/billing`. This mirrors the app's existing, already-accepted convention rather than introducing a new weakness, so it is not blocking, but is worth a follow-up `/raise-defect` for broader auth hardening across the whole billing surface.
