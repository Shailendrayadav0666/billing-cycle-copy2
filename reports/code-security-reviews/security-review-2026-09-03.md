# Security Baseline Review — Story 1.1 (Phase 2.5, diff-scoped)

**Scope**: `src/backend/main.py` new code (`charge_card`, `_calculate_proration`, `GET /api/billing/upgrade-preview`, `POST /api/billing/upgrade`) and `src/frontend/src/pages/Billing.jsx` changes. All 16 SECURITY-NN Security Baseline rules checked against this diff and the attack surface it reaches.

| Rule | Result |
|---|---|
| Encryption at rest/in transit | N/A — in-memory demo store, no persistence layer touched |
| Logging (no secrets/PII) | PASS — no new log statements added |
| Security headers | N/A — no new HTTP response headers logic; CORS middleware unchanged |
| Input validation | PASS — Pydantic `UpgradeRequest` validates the body; query param validated by FastAPI |
| SSRF | N/A — no outbound HTTP calls introduced (`charge_card` is a pure in-process function) |
| File uploads | N/A |
| Access control | 🟡 ADVISORY (not blocking) — see SEC-01 below; consistent with pre-existing app convention |
| CSRF | N/A — stateless API, no cookie-based session introduced |
| JWT security | N/A — no JWT used anywhere in this app |
| Network config | N/A |
| Credential management | PASS — no credentials introduced or handled |
| Session integrity | N/A — no session state introduced beyond the existing email-as-identity pattern |
| Supply chain | PASS — zero new dependencies (ARCH-05 verified: requirements.txt/package.json diffs are empty) |
| XML/XXE | N/A |
| Alerting | N/A |
| Error handling | PASS — declined/already-Premium paths return structured JSON with explicit status codes, no stack traces leaked |
| Cryptographic standards | N/A |

## Findings

**🟡 SEC-01 (advisory, not blocking) — Broken Access Control (OWASP A01:2025)**
`GET /api/billing/upgrade-preview` and `POST /api/billing/upgrade` both accept an arbitrary `email` (query param / body field) with no verification that the caller owns that identity — identical to the pre-existing `GET /api/billing`, `GET /api/tasks`, `POST /api/tasks` endpoints already in `main.py` before this story. This story's new endpoints do not introduce a new weakness; they extend the same, already-accepted authentication convention. No 🔴/🟠 finding raised. Recommend `/raise-defect` to track hardening the whole billing/tasks surface's identity verification as a separate piece of work, out of this story's scope.

**No 🔴 Blocker or 🟠 High findings on the changed surface.**
