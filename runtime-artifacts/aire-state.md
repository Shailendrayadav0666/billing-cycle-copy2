# AIRE State

- **Project**: Billing-Cycle Mid-Cycle Subscription Upgrade
- **Workflow Type**: epic
- **Started**: 2026-09-03T11:26:15Z
- **Current Phase**: PLANNING
- **Current Stage**: Requirements Analysis (Reverse Engineering skipped — Atlas full coverage)

## Tracker
- Type: LOCAL
- Parent Epic: Helix Solution Document 3157 — "Epic: Mid-Cycle Subscription Upgrade (Standard → Premium)"
- Epic URL: —
- Project Key / Repo / Org: —

## Helix MCP Binding
- **Server**: helix (mcp__helix__*)
- **Graph tool(s)**: codebase_agent_query, codebase_cypher_query, graph_change_impact — natural-language / Cypher / change-impact queries over the codebase knowledge graph
- **Docs tool(s)**: list_solution_documents_tool, get_solution_document_tool — Atlas solution documents (deepdive, epic, etc.)
- **Search tool(s)**: codebase_agent_query (doubles as free-text/graph search)
- **Estate / workspace id**: solution_id 874 ("Billing-Cycle-AIRE-V1-Demo"), repo Billing-Cycle @ main (bcec649e08f2dbec435c24066deae6a1d6d71192)
- **Resolved**: 2026-09-03T11:26:15Z

## Existing-System Context
- **Workspace type**: brownfield
- **Helix MCP**: connected
- **Source**: atlas
- **Components in scope**: backend/main.py (billing_data, billing route), frontend/src/pages/Billing.jsx, frontend/src/context/AuthContext.jsx
- **Atlas coverage**: 2 of 2 directly-touched components covered by deep-dive.md (13/13 analysis steps complete); knowledge-graph.md confirms no wider blast radius
- **Knowledge graph**: spec/plans/knowledge-graph.md
- **Recorded**: 2026-09-03T11:26:15Z

## Branching
- Base Branch: main
- Epic Branch: epic/3157-mid-cycle-subscription-upgrade
- Epic PR: (not raised — raised manually at cycle end via pr-generator)

## Extension Configuration
| Extension | Enabled | Decided At |
|---|---|---|
| Security Baseline | Yes (always mandatory) | Workflow start |
| Playwright Test Automation | Yes (always mandatory) | Workflow start |
| Resiliency Baseline | No | Requirements Analysis |
| Property-Based Testing | No | Requirements Analysis |

## Code Root
- `src/` — `src/backend` (FastAPI) and `src/frontend` (React/Vite). Matches default convention, no override needed.

## Reverse Engineering
- **Status**: SKIPPED — Atlas coverage Full (per `common/helix-atlas-integration.md` Section 5). `spec/plans/deep-dive.md` + `spec/plans/knowledge-graph.md` serve as the RE artifacts.

## team_size
- 2 (fixed default, never asked)

## Story Tracker

| Story | Title | Requires | Tracker ID | Status | PR | Merged | Start | End | Recorded |
|---|---|---|---|---|---|---|---|---|---|
| 1.1 | Upgrade CTA on Billing Page | — | LOCAL | 📋 Planned | — | — | — | — | — |
| 1.2 | Proration Confirmation Modal | 1.1 | LOCAL | 📋 Planned | — | — | — | — | — |
| 1.3 | Execute Upgrade & Dummy Payment | 1.1, 1.2 | LOCAL | 📋 Planned | — | — | — | — | — |
| 1.4 | Premium Plan Quotas & Billing Data | 1.3 | LOCAL | 📋 Planned | — | — | — | — | — |
| 1.5 | Already-Premium Guard | 1.1, 1.2, 1.3 | LOCAL | 📋 Planned | — | — | — | — | — |
