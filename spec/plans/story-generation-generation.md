# Story Generation Plan — Mid-Cycle Subscription Upgrade

- [x] `team_size`: fixed default `2` (never asked)
- [x] SPIDR slicing applied to the Epic's capabilities (Step 1.5) — see analysis below
- [ ] Ask the mandatory story-count question, wait for answer
- [ ] Generate `stories.md` (Epic header + all stories, `Covers` REQ-IDs) + `personas.md`
- [ ] Populate Story Tracker (Requires = TBD, Status = Ready for Development)
- [ ] Requirements full-coverage check (Rule 3)
- [ ] Story granularity/sizing-ceiling check (Step 18.6)
- [ ] Present GATE 1 for explicit approval

## Breakdown approach
**Feature-based**, following the Epic's own capability boundaries (CTA → Preview → Execute → Quotas → Guard) — each is a distinct user-observable capability with its own acceptance criteria.

## SPIDR analysis of the Epic's capabilities

| Axis | Finding |
|---|---|
| **Rules (R)** | Proration formula (own story: Preview) · Plan-flip quota rule (own story: Quotas) · Already-Premium guard rule (own story: Guard) |
| **Paths (P)** | Happy path (upgrade success) vs failure path (card declined) — genuinely different logic (mutate vs no-op + 402), not a one-line variation → separate stories |
| **Interfaces (I)** | Two new endpoints: `GET /upgrade-preview` (read-only) vs `POST /upgrade` (mutating) — separate concerns |
| **Data (D)** | Premium quota values are a distinct data variation from the base plan-flip → own story |
| **Steps (S)** | Upgrade is a 2-step user journey: CTA → confirm-modal-with-preview → execute. Each step is its own story. |

## Recommended story count

 **How many user stories should I create for this work?**

    Recommended: 5 stories (suggested range: 5-6)

   Why 5:
   - The Epic's own capability boundaries already form 5 SPIDR-clean single-purpose stories: (1) CTA visibility/badge, (2) preview endpoint + confirmation modal — one read-only round-trip, (3) execute endpoint + dummy gateway, happy AND failure path together (they are the same endpoint's two outcomes, both required to demo the gateway — splitting them would strand two half-features with no independent acceptance test since a "success-only" story can't be verified without the gateway's decline branch existing to prove determinism), (4) Premium quota/data mutation, (5) already-Premium guard on both endpoints.
   - Each story pairs one backend surface with its one consuming frontend interaction rather than shipping a backend endpoint nobody can observe yet — satisfies the INVEST "must remain independently valuable/demoable" override on the one-layer sizing ceiling.
   - Yields 5 independently-scoped stories >= team_size (2), with a natural dependency chain (1 -> 2 -> 3 -> 4/5) that still allows 4 and 5 to be worked in parallel once 3 merges.
   - Each story stays within the Step 1.5 ceilings: <=5 ACs per story, one dominant scenario class, no title conjunction.

   Reply with a number to override, or "ok"/"use recommended" to accept 5.
[Answer]: 1 — single story. Trade-off flagged (breaks the 5-AC/one-scenario-class sizing ceilings and the team_size=2 parallelism rule) and presented back to the user for confirmation; user explicitly confirmed "Force 1 story anyway." Honored as a deliberate, informed override per Step 9/10 — `target_story_count: 1` recorded in aire-state.md.
