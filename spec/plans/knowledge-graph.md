> **Source**: Atlas via Helix MCP
> **Server / tool**: helix MCP · codebase_agent_query (natural-language graph query over the codebase knowledge graph)
> **Estate**: Billing-Cycle-AIRE-V1-Demo (solution_id 874) / repo Billing-Cycle @ main (bcec649e08f2dbec435c24066deae6a1d6d71192)
> **Scope pulled**: Components named in the Epic — `backend/main.py`, `frontend/src/pages/Billing.jsx`, `frontend/src/context/AuthContext.jsx` — plus one-hop dependents/dependencies and any other reference to `billing_data`, `users`, or `/api/billing`
> **Fetched**: 2026-09-03T11:26:15Z
> **Freshness**: not reported by the graph query result

# Knowledge Graph — Billing Upgrade Scope

## Components in scope

| Component | Path | Role |
|---|---|---|
| `Billing.jsx` | `frontend/src/pages/Billing.jsx` | `Billing` component (line 100); fetches `GET /api/billing` (line 106). Renders plan card, usage meters. |
| `main.py` | `backend/main.py` | `billing` route handler (line 185); `billing_data` module-level dict (line 31) is the in-memory store keyed by email. |

## Graph findings

- The graph confirms `billing_data` (backend/main.py:31) is referenced only inside the `billing` route handler (backend/main.py:185) — no other backend module reads or writes it.
- `Billing.jsx` is the only frontend file querying `/api/billing`.
- No other component in the graph references `billing`, `billing_data`, or the `/api/billing` path — the blast radius of this epic is confined to these two files (plus the two new endpoints being added: `GET /api/billing/upgrade-preview`, `POST /api/billing/upgrade`).
- `AuthContext.jsx` was not returned as a direct node match on "billing", but per the Epic's own Referenced Paths it supplies the `token` (= email) used as the request parameter for all billing API calls — confirmed by inspection of `deep-dive.md`.

## Conclusion

Coverage is sufficient to skip local reverse-engineering generation. `deep-dive.md` (pulled from Atlas, 13/13 analysis steps complete) plus this scoped graph query give full existing-system truth for every component the Epic touches. Reverse Engineering stage is SKIPPED per `common/helix-atlas-integration.md` Section 5 ("Full" coverage row).
