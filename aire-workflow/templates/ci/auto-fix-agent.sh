#!/usr/bin/env bash
# auto-fix-agent.sh — CI self-repair via the Claude Code CLI (NOT the marketplace action, Section 6).
#
# 🔴 Input contract (Section 6.5):
#    PRIMARY      tests/.evals/_run/failed-gates.txt  — the authoritative list of what failed. Missing => this
#                 is a PIPELINE DEFECT: report and exit NON-ZERO. Never exit 0 on a job it did not repair.
#    SUPPLEMENTARY eval.json — per-criterion context. Absent => continue anyway, report as a finding.
#
# 🔴 The two proven lies this template fixes permanently:
#    1. mkdir -p every directory before writing the retry counter (Section 6.0.1 rule 2).
#    2. "No eval.json found" is NOT a free pass and NOT an infrastructure failure (Section 6.5). The
#       build failed; that fact is established by failed-gates.txt, not by the scorecard.
set -uo pipefail

CONFIG="tests/.evals/config.json"
RUN_DIR="tests/.evals/_run"
FAILED_GATES="${RUN_DIR}/failed-gates.txt"
BASE_SHA="${BASE_SHA:-}"

mkdir -p "$RUN_DIR"   # 🔴 rule 2 — before the counter write

report_and_exit() { echo "auto-fix-agent: $1" >&2; exit "${2:-1}"; }

# ── PRIMARY input ──
if [ ! -f "$FAILED_GATES" ]; then
  report_and_exit "PIPELINE DEFECT: ${FAILED_GATES} missing — the Verdict step must always produce it. Not exiting 0 on an unrepaired failure." 1
fi
GATES=(); while IFS= read -r line; do GATES+=("$line"); done < <(grep -v '^[[:space:]]*$' "$FAILED_GATES" || true)
if [ "${#GATES[@]}" -eq 0 ]; then
  report_and_exit "failed-gates.txt is empty but self-repair was triggered — cannot determine what to repair." 1
fi

# ── Retry budget ──
LIMIT=$(command -v jq >/dev/null 2>&1 && [ -f "$CONFIG" ] && jq -r '.retryLimitForSelfRepair // 3' "$CONFIG" || echo 3)
COUNTER="${RUN_DIR}/self-repair-attempt"
attempt=$(( ( $([ -f "$COUNTER" ] && cat "$COUNTER" || echo 0) ) + 1 ))
if [ "$attempt" -gt "$LIMIT" ]; then
  report_and_exit "retry limit ${LIMIT} reached — 3 retries ended. Please suggest next steps. Unresolved: ${GATES[*]}" 1
fi
echo "$attempt" > "$COUNTER"

# ── TRIAGE (Section 6.4): infrastructure-class failures are NEVER repaired ──
for g in "${GATES[@]}"; do
  case "$g" in
    sonar)
      # Real findings (conditions reported) => code-class. Auth/unreachable/timeout => infra => stop.
      if [ -f "${RUN_DIR}/sonar-conditions.txt" ] && [ -s "${RUN_DIR}/sonar-conditions.txt" ]; then
        : # code-class, repair below
      else
        report_and_exit "sonar failed WITHOUT reported conditions (auth/unreachable/timeout) — infrastructure, not a code defect. Not consuming a retry. Fix the Sonar connection/secret." 1
      fi
      ;;
  esac
done

# ── SUPPLEMENTARY input (never a precondition) ──
EVAL_JSON="$(find reports/eval-evidence -name eval.json 2>/dev/null | head -n1 || true)"
if [ -z "$EVAL_JSON" ]; then
  echo "auto-fix-agent: note — no eval.json found; repairing from failed-gates.txt + logs (Section 6.5). Reporting the missing scorecard as a separate finding." >&2
fi

command -v claude >/dev/null 2>&1 || report_and_exit "claude CLI not installed — cannot self-repair." 1

# 🔴 The BRIEF below tells Claude to commit its own fix (it has git tool access) — so "did the agent
#    change anything" can NOT be judged by working-tree dirtiness alone (Section 6 lesson: a clean
#    `git status` after the CLI call means "Claude already committed it", not "nothing happened").
#    Track HEAD movement too; only BOTH unchanged means a genuine no-op.
BEFORE_SHA="$(git rev-parse HEAD)"

BRIEF="The agentic eval pipeline failed on this PR.
Failed gates: ${GATES[*]}
Read failed-gates.txt (primary), the attached logs, and eval.json if present. Fix ONLY what failed.
Rules (non-negotiable):
  - Never delete, skip or weaken a test to go green.
  - Never suppress a finding (eslint-disable, # nosec, # type: ignore, ignore-lists).
  - Never lower a threshold in tests/.evals/config.json or edit a rubric.
  - Never edit spec/plans/architecture.md to make the J1 gate pass.
  - Never edit sonar-project.properties or the Quality Gate to pass a Sonar finding.
  - Fix the code. If the failing gate is something you can run yourself (lint, a unit test, a build
    command), re-run it and confirm it is green.
  - Do NOT try to invoke or re-run the J1_architecture / J2_security judge gates yourself. Scoring
    them means shelling out to claude again from inside your own tool call, which cannot authenticate
    (credentials do not propagate to a nested claude invocation) — that failure is expected, not a bug
    worth reporting. This script re-verifies J1/J2 for real after your turn ends; just fix the cited
    criteria/citations from eval.json and stop.
Commit with:  fix(ci): self-repair attempt ${attempt} — ${GATES[*]}"

# 🔴 headless/permission flags resolved from `claude --help` at GENERATION time (Section 6.0) —
#    the generator writes the resolved invocation between the markers below, never assumed from memory.
# >>> CLAUDE_REPAIR_INVOCATION START <<<
printf '%s' "$BRIEF" | claude || report_and_exit "the repair CLI invocation failed on attempt ${attempt}." 1
# >>> CLAUDE_REPAIR_INVOCATION END <<<

# ── Verify the agent actually changed something ──
# Claude may have committed the fix itself (per the BRIEF) — that leaves the tree clean but HEAD
# moved. Only a clean tree AND an unmoved HEAD means it genuinely made no changes.
AFTER_SHA="$(git rev-parse HEAD)"
if [ "$AFTER_SHA" = "$BEFORE_SHA" ] && [ -z "$(git status --porcelain)" ]; then
  report_and_exit "self-repair produced no changes on attempt ${attempt} — nothing committed. PR stays red." 1
fi

# 🔴 D7_secrets is the ONE gate a forward commit can be structurally unable to clear: gitleaks scans
#    `--log-opts BASE..HEAD`, i.e. every commit's OWN patch in that range — not the final tree. A
#    finding anchored to a commit that was ALREADY pushed to origin before this attempt started stays
#    in that history forever; no later commit can retroactively edit it. Observed in production:
#    self-repair correctly fixed the actual code (2 of 3 D7 findings' source locations, plus D1_lint),
#    re-verified, and found D7_secrets still red with the SAME finding count — because the flagged text
#    is permanently baked into an already-pushed commit's patch, not because the fix didn't work.
#    Refusing to commit in that case would discard real, valuable fixes for no benefit — but SILENTLY
#    committing as if D7 passed would hide a genuinely unresolved finding. Do neither: commit the real
#    fixes, and say plainly that D7_secrets needs a human decision.
d7_only_history_anchored_remaining() {
  local gates_file gitleaks_report origin_ref commit
  gates_file="$(find reports/eval-evidence -name 'static-results.json.gates' 2>/dev/null | head -n1 || true)"
  [ -n "$gates_file" ] && [ -f "$gates_file" ] || return 1

  local failing=()
  while IFS=$'\t' read -r g s _; do
    case "$s" in FAIL|ERROR) failing+=("$g") ;; esac
  done < "$gates_file"
  # Must be the ONLY thing still failing — anything else means real fixable work remains.
  [ "${#failing[@]}" -eq 1 ] && [ "${failing[0]}" = "D7_secrets" ] || return 1

  gitleaks_report="$(find reports/eval-evidence -name 'gitleaks-delta.json' 2>/dev/null | head -n1 || true)"
  [ -n "$gitleaks_report" ] && [ -f "$gitleaks_report" ] && command -v jq >/dev/null 2>&1 || return 1

  origin_ref="origin/${GITHUB_HEAD_REF:-HEAD}"
  git fetch origin "${GITHUB_HEAD_REF:-HEAD}" >/dev/null 2>&1 || true

  while IFS= read -r commit; do
    [ -z "$commit" ] && continue
    git merge-base --is-ancestor "$commit" "$origin_ref" 2>/dev/null || return 1
  done < <(jq -r '.[].Commit // empty' "$gitleaks_report" 2>/dev/null | sort -u)
  return 0
}

# ── rule 4: re-run the evals BEFORE committing; a commit that does not re-verify wastes a retry ──
if [ -n "$BASE_SHA" ]; then
  bash tests/.evals/scripts/run-static-evals.sh "$BASE_SHA"; static_rc=$?
  bash tests/.evals/scripts/run-evals.sh "$BASE_SHA"; evals_rc=$?
  if [ "$static_rc" -ne 0 ] || [ "$evals_rc" -ne 0 ]; then
    if d7_only_history_anchored_remaining; then
      echo "auto-fix-agent: D7_secrets remains red — every remaining finding is anchored to an already-pushed commit (gitleaks' own --log-opts BASE..HEAD commit-range scan); no forward commit can clear it. Proceeding to commit the real fix(es) made for the other gate(s). D7_secrets needs a human decision: rebase to scrub the secret from that commit and force-push, or (only if it is a rotated/false-positive credential) add a scoped gitleaks allowlist entry for that exact fingerprint — never a blanket suppression." >&2
    else
      report_and_exit "re-verification still FAILS after repair attempt ${attempt} — not committing an unverified fix." 1
    fi
  fi
fi

# 🔴 A fresh GH Actions runner has no git identity configured — `git commit` fails outright
#    ("Author identity unknown... fatal: empty ident name") even after a fully correct repair, wasting
#    a retry attempt on something that was never a code problem. `--local` (not `--global`) scopes it to
#    this checkout only. Same bot-identity convention as smoke-test-epic.sh's `aire-ci-smoke` commits.
git config --local user.name "aire-self-repair"
git config --local user.email "aire-self-repair@localhost"

# Claude may have already committed its own fix inside the CLI call above. Only create an extra
# commit for whatever it left uncommitted — never treat "nothing left to stage" as a failure.
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "fix(ci): self-repair attempt ${attempt} — ${GATES[*]}" || report_and_exit "commit failed on attempt ${attempt}." 1
fi
git push origin HEAD:"${GITHUB_HEAD_REF:-HEAD}" || report_and_exit "push failed on attempt ${attempt}." 1

echo "auto-fix-agent: attempt ${attempt} committed and pushed for gates: ${GATES[*]}"
exit 0
