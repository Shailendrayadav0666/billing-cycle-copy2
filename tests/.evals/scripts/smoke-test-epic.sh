#!/usr/bin/env bash
# smoke-test-epic.sh — ONE-TIME, epic-level pre-handoff validation that the generated CI pipeline
# actually works in THIS repo's environment (common/ci-pipeline-generation.md Section 4.0.6).
#
# 🔴 What this validates: dependency-install conflicts, tool-installation quirks, whether the
#    EXISTING test suite even runs, and whether self-repair itself works end-to-end — all properties
#    of the environment/baseline codebase, not of any story's changes.
# 🔴 What this does NOT validate: delta-scoped gate accuracy (D1-D7 "new findings", unitCoverage's
#    multi-report matching, behavior tiers, J1/J2 judge scoring) — those need a real diff to mean
#    anything, and this PR is deliberately a zero-diff scratch branch. The first real story's PR is
#    still what exercises that logic for the first time. Never claim this proves the whole pipeline
#    is correct — it proves the environment is viable to start building on.
#
# Contract:
#   arg1  EPIC_BRANCH — the branch to validate against, e.g. epic/EPIC-123-title (required)
#   arg2  EPIC_ID     — used to name the scratch branch/PR, e.g. EPIC-123 (required)
#   Reuses retryLimitForSelfRepair from tests/.evals/config.json (ci-pipeline-generation.md Section 4.0.6:
#   "reuse the existing budget; do not invent a second one") — initial run + up to that many
#   self-repair follow-up runs, same budget self-repair itself uses for real story-code fixes.
#   Exits 0 on a passing smoke test (scratch branch merged into EPIC_BRANCH, deleted).
#   Exits 1 on exhaustion — the draft PR is left OPEN for human inspection, nothing is merged.
#   Exits 2 on a setup/tooling problem (gh not installed/authenticated, git failure, etc.)
set -uo pipefail

EPIC_BRANCH="${1:-}"
EPIC_ID="${2:-}"

fail() { echo "smoke-test-epic: ERROR: $*" >&2; }
note() { echo "smoke-test-epic: $*"; }

if [ -z "$EPIC_BRANCH" ] || [ -z "$EPIC_ID" ]; then
  fail "usage: smoke-test-epic.sh <epic-branch> <epic-id>"
  exit 2
fi
if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI not installed — cannot open or watch the smoke-test PR"
  exit 2
fi
if ! gh auth status >/dev/null 2>&1; then
  fail "gh CLI not authenticated — run 'gh auth login' first"
  exit 2
fi

# 🔴 Fixed at 1 (deliberate override) — the smoke test never reads retryLimitForSelfRepair from
#    tests/.evals/config.json for its own budget. This is a smaller, separately-chosen cap for the epic-level
#    environment check specifically, not the real self-repair budget used for actual story-code fixes.
RETRY_LIMIT=1

# Filesystem-safe slug from the epic id (mirrors resolve-eval-key.sh's own sanitization).
SLUG="$(printf '%s' "$EPIC_ID" | tr -cs 'A-Za-z0-9._-' '-')"
SCRATCH_BRANCH="ci/epic-smoke-${SLUG}"

note "cutting scratch branch ${SCRATCH_BRANCH} from ${EPIC_BRANCH}"
if ! git fetch origin "$EPIC_BRANCH" 2>/dev/null; then
  fail "could not fetch ${EPIC_BRANCH} from origin"
  exit 2
fi
# 🔴 Pushing origin/<epic-branch> straight to refs/heads/<scratch> makes both refs point at the SAME
#    commit — GitHub's API then refuses to open a PR ("No commits between ... (createPullRequest)"),
#    since head and base are identical. An empty commit (same tree, new commit object) gives the
#    scratch branch a distinct SHA — still a genuine zero-diff smoke test, just a real PR is possible.
SMOKE_SHA="$(GIT_COMMITTER_NAME="aire-ci-smoke" GIT_COMMITTER_EMAIL="aire-ci-smoke@localhost" \
  GIT_AUTHOR_NAME="aire-ci-smoke" GIT_AUTHOR_EMAIL="aire-ci-smoke@localhost" \
  git commit-tree "origin/${EPIC_BRANCH}^{tree}" -p "origin/${EPIC_BRANCH}" \
  -m "chore(ci): zero-diff smoke commit for ${EPIC_ID}" 2>/dev/null)"
if [ -z "$SMOKE_SHA" ]; then
  fail "could not create the empty smoke-test commit"
  exit 2
fi
if ! git push origin "${SMOKE_SHA}:refs/heads/${SCRATCH_BRANCH}" 2>/dev/null; then
  fail "could not create ${SCRATCH_BRANCH} on origin from ${EPIC_BRANCH}"
  exit 2
fi

note "opening draft PR: ${SCRATCH_BRANCH} -> ${EPIC_BRANCH}"
PR_URL=$(gh pr create \
  --draft \
  --base "$EPIC_BRANCH" \
  --head "$SCRATCH_BRANCH" \
  --title "[CI-SMOKE] Pre-handoff validation — ${EPIC_ID}" \
  --body "Automated, zero-diff smoke test of the generated CI pipeline before dev-implement handoff (ci-pipeline-generation.md Section 4.0.6). Safe to ignore — this PR is merged and its scratch branch deleted automatically on a pass, or left open for inspection on failure. Never merge this manually into anything but ${EPIC_BRANCH}." \
  2>&1) || { fail "gh pr create failed: $PR_URL"; exit 2; }
PR_NUMBER=$(printf '%s' "$PR_URL" | grep -oE '[0-9]+$')
note "opened ${PR_URL}"

cleanup_on_abort() {
  fail "aborting — leaving ${PR_URL} open for inspection, scratch branch ${SCRATCH_BRANCH} NOT deleted"
}
trap cleanup_on_abort ERR

# Wait for the first run to be scheduled (opening a PR does not instantly have a queued run).
run_id=""
waited=0
while [ "$waited" -lt 60 ]; do
  run_id=$(gh run list --branch "$SCRATCH_BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null)
  [ -n "$run_id" ] && break
  sleep 5; waited=$((waited + 5))
done
if [ -z "$run_id" ]; then
  trap - ERR
  fail "no workflow run appeared for ${SCRATCH_BRANCH} within 60s after opening the PR"
  cleanup_on_abort
  exit 1
fi

max_attempts=$((RETRY_LIMIT + 1))   # the initial run, plus up to RETRY_LIMIT self-repair follow-up runs
attempt=1
passed=0
while [ "$attempt" -le "$max_attempts" ]; do
  note "watching run ${run_id} (attempt ${attempt}/${max_attempts})"
  if gh run watch "$run_id" --exit-status >/dev/null 2>&1; then
    note "run ${run_id} PASSED"
    passed=1
    break
  fi
  note "run ${run_id} FAILED — failed-step logs:"
  gh run view "$run_id" --log-failed 2>&1 | sed 's/^/  /' || note "(could not fetch failed-step logs for run ${run_id} — inspect ${PR_URL} manually)"
  note "checking whether self-repair pushed a fix"
  new_run_id=""
  waited=0
  while [ "$waited" -lt 120 ]; do
    sleep 10; waited=$((waited + 10))
    candidate=$(gh run list --branch "$SCRATCH_BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null)
    if [ -n "$candidate" ] && [ "$candidate" != "$run_id" ]; then
      new_run_id="$candidate"
      break
    fi
  done
  if [ -z "$new_run_id" ]; then
    note "no new run appeared — self-repair did not push a fix, or exhausted its own retries"
    break
  fi
  run_id="$new_run_id"
  attempt=$((attempt + 1))
done

trap - ERR

if [ "$passed" -eq 1 ]; then
  note "merging ${PR_URL} into ${EPIC_BRANCH} and deleting ${SCRATCH_BRANCH}"
  if ! gh pr merge "$PR_NUMBER" --merge --delete-branch 2>&1; then
    fail "smoke test passed but the merge failed — resolve ${PR_URL} manually"
    exit 1
  fi
  note "smoke test PASSED — ${EPIC_BRANCH} is validated, safe to hand off to dev-implement"
  exit 0
fi

attempts_run=$((attempt > max_attempts ? max_attempts : attempt))
fail "SMOKE TEST FAILED after ${attempts_run} attempt(s). ${PR_URL} is left OPEN for inspection."
fail "3 retries ended. Please suggest next steps."
fail "Development Handoff is BLOCKED until this is resolved — see ci-pipeline-generation.md Section 4.0.6."
exit 1
