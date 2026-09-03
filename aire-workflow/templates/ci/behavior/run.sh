#!/usr/bin/env bash
# behavior/run.sh — the SINGLE entry point for the Gherkin tiers. The developer, AIRE's local gate and
# CI all call `./tests/.evals/behavior/run.sh <tier>` so tier membership can never drift (Section 4.1b).
#
#   b1  this work unit's feature file only
#   b2  every OTHER feature file under spec/behavior/
#   b3  the whole cycle plus spec/behavior.feature (cross-story journeys) — last unit / base-branch PR
#
# 🔴 NO STUBS. A tier that cannot resolve any feature files exits NON-ZERO with the reason — it never
#    prints "ok" and exits 0 (Section 5.0). Tier membership is read from the spec/ layout here, never
#    duplicated in YAML.
#
# 🔴 ONE legitimate exception: exit 3 = N/A, reserved for spec/behavior/ containing ZERO feature files
#    of ANY kind — meaning no story has EVER been dev-implement'd in this epic yet (the pre-story /
#    epic-level-smoke-test case, ci-pipeline-generation.md Section 4.0.6's own documented "does NOT
#    validate" scope). A tier that finds none of ITS OWN files while OTHER feature files exist is still
#    a real contract violation and stays exit 2 (ERROR) — only total absence is N/A.
set -uo pipefail

TIER="${1:-}"
BEHAVIOR_DIR="spec/behavior"
CROSS_STORY="spec/behavior.feature"

[ -n "$TIER" ] || { echo "run.sh: no tier supplied (b1|b2|b3)" >&2; exit 2; }

# The generator resolves the concrete runner invocation for this stack (cucumber-js / pytest-bdd /
# mvn verify / godog / reqnroll) between the markers below (Section 3). It MUST fail the process on a
# scenario failure and MUST NOT be replaced by an `echo ok`.
run_features() { # $@ = feature files
  [ "$#" -gt 0 ] || { echo "run.sh: tier ${TIER} resolved zero feature files" >&2; return 2; }
  # >>> STACK-RESOLVED BEHAVIOUR RUNNER START <<<
  echo "run.sh: no behaviour runner resolved for this stack — generation defect (ERROR, not a pass)" >&2
  return 2
  # >>> STACK-RESOLVED BEHAVIOUR RUNNER END <<<
}

no_stories_yet() { # true iff spec/behavior/ has literally zero *.feature files (not just zero for this tier)
  [ -z "$(ls -1 "${BEHAVIOR_DIR}"/*.feature 2>/dev/null || true)" ]
}

case "$TIER" in
  b1)
    unit_feature="$(ls -1 "${BEHAVIOR_DIR}"/story-*.feature 2>/dev/null | tail -n1 || true)"
    if [ -z "$unit_feature" ]; then
      if no_stories_yet; then
        echo "run.sh: b1 N/A — no story has been dev-implement'd in this epic yet (spec/behavior/ has zero feature files)" >&2
        exit 3
      fi
      echo "run.sh: b1 found no story feature file (other feature files exist — this story's own contract is missing)" >&2
      exit 2
    fi
    run_features "$unit_feature" ;;
  b2)
    mapfile -t others < <(ls -1 "${BEHAVIOR_DIR}"/*.feature 2>/dev/null || true)
    if [ "${#others[@]}" -eq 0 ]; then
      echo "run.sh: b2 N/A — no story has been dev-implement'd in this epic yet (spec/behavior/ has zero feature files)" >&2
      exit 3
    fi
    run_features "${others[@]}" ;;
  b3)
    mapfile -t all < <(ls -1 "${BEHAVIOR_DIR}"/*.feature 2>/dev/null || true)
    [ -f "$CROSS_STORY" ] && all+=("$CROSS_STORY")
    if [ "${#all[@]}" -eq 0 ]; then
      echo "run.sh: b3 N/A — no story has been dev-implement'd in this epic yet, and no cross-story spec/behavior.feature exists" >&2
      exit 3
    fi
    run_features "${all[@]}" ;;
  *)
    echo "run.sh: unknown tier '${TIER}' (expected b1|b2|b3)" >&2; exit 2 ;;
esac
