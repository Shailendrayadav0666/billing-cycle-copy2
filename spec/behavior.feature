# Cycle-level cross-story journeys — spec/behavior.feature
#
# This cycle contains exactly ONE story (Story 1.1, by explicit user override of the
# recommended 5-story breakdown — see spec/plans/story-generation-generation.md and
# runtime-artifacts/audit.md). There is therefore no seam BETWEEN stories for a cross-story
# journey to exercise: every acceptance criterion of this epic is already owned end-to-end by
# Story 1.1's own behavior spec (spec/behavior/story-1.1.feature, written at dev-implement time).
#
# Per common/behavior-spec.md: "Genuinely cross-unit journeys only, never copies of per-story
# scenarios; if the requirement has none, record that explicitly." Recorded explicitly here.
# This file intentionally contains no scenarios. The B3 tier (spec/plans architecture ->
# tests/.evals/config.json behaviorB3) will report N/A with this reason on the single work unit's
# review pass, per common/eval-framework.md Section 8 ("B3 would run but other work units are
# still open" does not apply either — there simply is no second unit to integrate with).

Feature: Mid-Cycle Subscription Upgrade — cross-story journeys
  No cross-story scenarios apply. See the header comment above.
