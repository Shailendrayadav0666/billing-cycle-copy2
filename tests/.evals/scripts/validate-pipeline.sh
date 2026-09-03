#!/usr/bin/env bash
# validate-pipeline.sh — LAYER 2: the non-skippable local gate run AFTER slot substitution and BEFORE
# the pipeline is committed (CI-DETERMINISM-PLAN Section 4). This is "run locally, fix, then push".
#
# 🔴 A non-zero exit means the pipeline is NOT committed — it is fixed and re-validated (max 3 attempts,
#    then HALT per Section 4.0.4). This script never mutates the repo; it only inspects.
#
# Usage: bash tests/.evals/scripts/validate-pipeline.sh [base-sha]
set -uo pipefail

WF=".github/workflows/agentic-eval-pipeline.yml"
CONFIG="tests/.evals/config.json"
BASE_SHA="${1:-}"
rc=0
note() { echo "  $*"; }
check_fail() { echo "FAIL  $1"; rc=1; }
check_ok() { echo "ok    $1"; }

echo "validate-pipeline: checking ${WF}"

# A "code view" of the workflow with whole-line YAML comments stripped, so prose in comments (which may
# legitimately mention `|| true`, ${SLOT}, <placeholder> as documentation) never trips a check. Inline
# `#` inside a run: block is left alone — those are shell comments and rare in the generated file.
CODEVIEW="$(mktemp)"
if [ -f "$WF" ]; then grep -vE '^[[:space:]]*#' "$WF" > "$CODEVIEW" || true; fi
cleanup() { rm -f "$CODEVIEW"; }
trap cleanup EXIT

# ── V-slot: no leftover ${SLOT} / GENERATE / placeholder markers ──
# 🔴 Exclude legitimate RUNTIME shell vars the templates set via step env: (e.g. ${EVAL_KEY},
#    ${BASE_SHA}) — those are NOT unresolved template slots. Everything else in ${UPPER_CASE} is.
if [ ! -f "$WF" ]; then check_fail "workflow file $WF does not exist"; else
  slot_hits="$(grep -nE '\$\{[A-Z_]+\}|# GENERATE:|<[a-z][a-z-]*>|>>> [A-Z_ ]+ (START|END) <<<' "$CODEVIEW" \
    | grep -vE '\$\{(EVAL_KEY|BASE_SHA|GITHUB_[A-Z_]+)\}' || true)"
  if [ -n "$slot_hits" ]; then
    echo "$slot_hits"
    check_fail "unresolved slot/placeholder/marker remains in the committed workflow (V14)"
  else check_ok "no unresolved slots or placeholders (V14)"; fi
fi

# ── V1: YAML parses ──
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml,sys; yaml.safe_load(open('$WF'))" 2>/tmp/vp_yaml.err; then
    check_ok "YAML parses (V1)"
  else check_fail "YAML parse error (V1): $(cat /tmp/vp_yaml.err)"; fi
else note "python3 not available — YAML parse (V1) not run"; fi

# ── V2: actionlint ──
if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$WF" 2>/tmp/vp_al.err; then check_ok "actionlint clean (V2)";
  else check_fail "actionlint errors (V2): $(cat /tmp/vp_al.err)"; fi
else note "actionlint: not available — schema check (V2) not run (record this in the announcement)"; fi

# ── V-manifest: gates[] appears in BOTH the verdict tally and the eval.json schema ──
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  # Static gate ids are computed inside run-evals; here we assert the ci block is well-formed and that
  # the verdict step in the workflow tallies the five aggregate outcomes the templates emit.
  gate_count=$(jq -r '.ci.gates | length' "$CONFIG" 2>/dev/null || echo 0)
  [ "${gate_count:-0}" -gt 0 ] && check_ok "ci.gates present (${gate_count} gates)" || check_fail "ci.gates empty (manifest not filled)"
  for agg in static unit coverage behavior judge sonar; do
    grep -q "\"${agg}:" "$WF" || check_fail "verdict tally missing aggregate outcome '${agg}' (V8/V18)"
  done
  # eval.json schema check: run-evals must iterate ci.gates (grep the shipped script)
  if [ -f "tests/.evals/scripts/run-evals.sh" ]; then
    grep -q 'ci.gates' tests/.evals/scripts/run-evals.sh || check_fail "run-evals.sh does not iterate ci.gates — scorecard can drift (4.0c.3)"
  fi
else check_fail "$CONFIG or jq missing — cannot validate the manifest"; fi

# ── V4: every file the workflow/scripts reference actually exists ──
for f in "tests/.evals/config.json" "tests/.evals/rubrics/architecture-rubric.json" "tests/.evals/rubrics/security-rubric.json" "tests/.evals/behavior/run.sh"; do
  if [ -f "$f" ]; then check_ok "referenced file exists: $f (V4)"; else check_fail "referenced file missing: $f (V4)"; fi
done
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  sonar_enabled=$(jq -r '.sonarqube.enabled // false' "$CONFIG")
  if [ "$sonar_enabled" = "true" ]; then
    if [ -f "sonar-project.properties" ]; then check_ok "sonar-project.properties exists (sonarqube.enabled=true) (V4)"
    else check_fail "sonarqube.enabled=true but sonar-project.properties is missing (V4)"; fi
  fi
fi

# ── V11: EVAL_KEY resolves via resolve-eval-key.sh output, never the raw branch ref ──
if [ -f "$WF" ]; then
  if grep -qE 'EVAL_KEY:\s*"\$\{\{\s*github\.head_ref\s*\}\}"' "$CODEVIEW"; then
    check_fail "EVAL_KEY set directly from github.head_ref — branch refs contain '/', this must go through resolve-eval-key.sh (V11)"
  elif grep -q 'steps.evalkey.outputs.key' "$CODEVIEW"; then
    check_ok "EVAL_KEY resolves via resolve-eval-key.sh output (V11)"
  else
    check_fail "no EVAL_KEY resolution via steps.evalkey.outputs.key found (V11)"
  fi
fi

# ── V12: every generated script creates its output directories before writing ──
for s in "tests/.evals/scripts/run-static-evals.sh" "tests/.evals/scripts/run-evals.sh" "tests/.evals/scripts/auto-fix-agent.sh"; do
  if [ -f "$s" ]; then
    if grep -q 'mkdir -p' "$s"; then check_ok "$s creates its directories before writing (V12)"
    else check_fail "$s has no 'mkdir -p' — a clean checkout will hit 'No such file or directory' (V12)"; fi
  fi
done

# ── V15: verify job uploads the eval-results artifact self-repair's download-artifact depends on ──
if [ -f "$WF" ]; then
  if grep -q 'actions/upload-artifact' "$WF" && grep -q 'name: eval-results' "$WF"; then
    check_ok "verify job uploads eval-results artifact (V15)"
  else
    check_fail "no actions/upload-artifact step named 'eval-results' found — self-repair's download-artifact will find nothing (V15)"
  fi
fi

# ── V16/V22: for every version-check line in an "Install eval tools" step, an install command for
#    that same tool appears earlier in the SAME block. A version check with no preceding install
#    only "works" by accident, when the runner image happens to ship the tool already. ──
check_install_order() {
  awk '
    BEGIN {
      n = split("python3 pip pip3 node npm npx git jq curl bash sh podman docker echo printf exit tar gitleaks_version", a, " ")
      for (i=1;i<=n;i++) allowed[a[i]]=1
    }
    /^      - name: "Install eval tools"/ { instep=1; delete seen; next }
    instep && /^      - name:/ { instep=0 }
    instep && /^  [a-zA-Z-]+:/ { instep=0 }
    instep {
      line=$0
      is_comment = (line ~ /^[[:space:]]*#/)
      is_check = (line ~ /--version/ && line ~ /\|\|/) || (line ~ /[[:space:]]version[[:space:]]/ && line ~ /\|\|/) || (line ~ /not found after install/)
      if (is_check && !is_comment) {
        t=line; gsub(/^[[:space:]]+/, "", t); split(t, arr, " ")
        if (arr[1] == "command" && arr[2] == "-v") { tool = arr[3] } else { tool = arr[1] }
        if (tool != "" && !(tool in allowed) && !(tool in seen)) {
          print tool
        }
      } else if (!is_comment) {
        m = split(line, toks, /[ \t"=]+/)
        for (i=1;i<=m;i++) if (toks[i] != "") seen[toks[i]] = 1
      }
    }
  ' "$WF"
}
if [ -f "$WF" ]; then
  missing="$(check_install_order)"
  if [ -n "$missing" ]; then
    while IFS= read -r t; do check_fail "version check for '$t' with no preceding install in the same 'Install eval tools' step (V16/V22)"; done <<< "$missing"
  else
    check_ok "every version check in 'Install eval tools' is preceded by its install in the same step (V16/V22)"
  fi
fi

# ── V24: after any pip-based eval-tool install, pip check must run before the version checks — this
#    is what catches a pinned tool's transitive dependency graph breaking against an unpinned
#    ecosystem package (Section 3.2.1's setuptools/pkg_resources failure — the original bug). ──
check_pip_check() {
  awk '
    /^      - name: "Install eval tools"/ { instep=1; has_pip=0; has_check=0; next }
    instep && /^      - name:/ { if (has_pip && !has_check) print "MISSING"; instep=0 }
    instep && /^  [a-zA-Z-]+:/ { if (has_pip && !has_check) print "MISSING"; instep=0 }
    instep && /pip install/ { has_pip=1 }
    instep && /pip check/ { has_check=1 }
    END { if (instep && has_pip && !has_check) print "MISSING" }
  ' "$WF"
}
if [ -f "$WF" ]; then
  pipcheck_missing="$(check_pip_check)"
  if [ -n "$pipcheck_missing" ]; then
    check_fail "an 'Install eval tools' step runs pip install but never runs 'pip check' before its version checks (V24)"
  else
    check_ok "pip check runs after every pip-based eval-tool install, or no pip install is used (V24)"
  fi
fi

note "V23 (clean-room dry-run) cannot be verified statically from this file — confirm Section 4.0.1a's clean-room dry-run was actually performed before this commit."

# ── V8: every gate step isolated (id + continue-on-error), exactly one verdict, sonar last & always() ──
if [ -f "$WF" ]; then
  if grep -qE '\|\|[[:space:]]*true|\|\|[[:space:]]*exit 0|;[[:space:]]*true' "$CODEVIEW"; then
    check_fail "forbidden '|| true' / '|| exit 0' / '; true' in a step (V8)"
  else check_ok "no '|| true' style masking (V8)"; fi
  vcount=$(grep -cE '^[[:space:]]*-[[:space:]]*name:[[:space:]]*"Verdict"' "$WF" || true)
  [ "${vcount:-0}" -eq 1 ] && check_ok "exactly one Verdict step (V8)" || check_fail "expected exactly one Verdict step, found ${vcount} (V8)"
fi

# ── V10: trigger covers base branch + every integration prefix from the manifest ──
if [ -f "$WF" ] && [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  v10_ok=1
  base=$(jq -r '.ci.baseBranch // "main"' "$CONFIG")
  grep -q "\"${base}\"" "$WF" || { check_fail "trigger does not name base branch '${base}' (V10)"; v10_ok=0; }
  while read -r p; do
    [ -z "$p" ] && continue
    grep -q "'${p}/\*\*'" "$WF" || { check_fail "trigger missing integration prefix '${p}/**' (V10)"; v10_ok=0; }
  done < <(jq -r '.ci.integrationBranchPrefixes[]?' "$CONFIG")
  [ "$v10_ok" -eq 1 ] && check_ok "trigger covers base branch + every integration prefix (V10)"
fi

# ── V13: self-repair re-runs BOTH eval scripts before committing — a commit that never re-verifies
#    wastes a retry attempt on an unverified fix. ──
if [ -f "tests/.evals/scripts/auto-fix-agent.sh" ]; then
  af="tests/.evals/scripts/auto-fix-agent.sh"
  commit_line=$(grep -n 'git commit' "$af" | head -1 | cut -d: -f1 || true)
  static_line=$(grep -n 'run-static-evals' "$af" | head -1 | cut -d: -f1 || true)
  evals_line=$(grep -n 'run-evals\.sh' "$af" | tail -1 | cut -d: -f1 || true)
  if [ -n "$commit_line" ] && [ -n "$static_line" ] && [ -n "$evals_line" ] && \
     [ "$static_line" -lt "$commit_line" ] && [ "$evals_line" -lt "$commit_line" ]; then
    check_ok "auto-fix-agent.sh re-runs run-static-evals.sh and run-evals.sh before git commit (V13)"
  else
    check_fail "auto-fix-agent.sh does not clearly re-run both eval scripts before git commit (V13)"
  fi
fi

# ── V19: self-repair never exits 0 without repairing — every real 'exit 0' must follow a commit ──
if [ -f "tests/.evals/scripts/auto-fix-agent.sh" ]; then
  af="tests/.evals/scripts/auto-fix-agent.sh"
  af_codeview="$(mktemp)"
  grep -vE '^[[:space:]]*#' "$af" > "$af_codeview"
  last_commit_line=$(grep -n 'git commit' "$af_codeview" | tail -1 | cut -d: -f1 || true)
  v19_bad=0
  while IFS=: read -r ln content; do
    [ -z "$ln" ] && continue
    if [ -z "$last_commit_line" ] || [ "$ln" -lt "$last_commit_line" ]; then
      v19_bad=1
      echo "  early exit 0 at line $ln: $content"
    fi
  done < <(grep -n 'exit 0' "$af_codeview" || true)
  rm -f "$af_codeview"
  if [ "$v19_bad" -eq 1 ]; then
    check_fail "auto-fix-agent.sh has an 'exit 0' reachable before a successful commit — self-repair must never claim success without repairing (V19)"
  else
    check_ok "every 'exit 0' in auto-fix-agent.sh follows a successful commit (V19)"
  fi
fi

# ── V20: no deferred-setup N/A — these phrases paired with N/A status are ERROR, never N/A ──
v20_hit=0
for s in "tests/.evals/scripts/run-static-evals.sh" "tests/.evals/scripts/run-evals.sh" "tests/.evals/scripts/auto-fix-agent.sh"; do
  [ -f "$s" ] || continue
  hits=$(grep -nE "N/A" "$s" | grep -Ei 'yet|TODO|not wired|not bootstrapped|not installed|not enabled|pending' || true)
  if [ -n "$hits" ]; then v20_hit=1; echo "$hits"; fi
done
if [ "$v20_hit" -eq 1 ]; then
  check_fail "an 'N/A' reason contains a deferred-setup phrase (yet/TODO/not wired/pending/...) — this must be ERROR, not N/A (V20, eval-framework.md Section 2.4.2)"
else
  check_ok "no deferred-setup language paired with N/A (V20)"
fi

# ── V7: within the stack-resolved D-gates region, every line is delta_diff/record — never a bare
#    whole-tree tool invocation (Section 4.0b's whole-tree-verdict bug). ──
if [ -f "tests/.evals/scripts/run-static-evals.sh" ]; then
  region=$(awk '/>>> STACK-RESOLVED D-GATES START <<</{flag=1; next} />>> STACK-RESOLVED D-GATES END <<</{flag=0} flag' tests/.evals/scripts/run-static-evals.sh)
  bad=$(echo "$region" | grep -vE '^[[:space:]]*($|#|delta_diff |record )' || true)
  if [ -n "$bad" ]; then
    check_fail "bare command in the stack-resolved D-gates region (not wrapped in delta_diff/record) — whole-tree verdict risk (V7)"
    echo "$bad"
  else
    check_ok "stack-resolved D-gates region contains only delta_diff/record calls (V7)"
  fi
fi

# ── V9 (partial — see note below): no hardcoded PASS/N-A literal bypassing record/Record ──
for s in "tests/.evals/scripts/run-static-evals.sh" "tests/.evals/scripts/run-evals.sh"; do
  [ -f "$s" ] || continue
  hits=$(grep -nE '"status"[[:space:]]*:[[:space:]]*"(PASS|N/A)"' "$s" | grep -v 'rubric %s absent' || true)
  if [ -n "$hits" ]; then
    check_fail "hardcoded status literal outside the documented rubric-absent N/A fallback in $s — possible stub (V9)"
    echo "$hits"
  else
    check_ok "no hardcoded PASS/N-A literal outside the documented rubric-absent fallback in $s (V9)"
  fi
done
note "V9's full requirement — prove each script can FAIL against a deliberately broken input — needs fault injection and is not fully automated here. The check above only catches the hardcoded-literal half of Section 5.0."

# ── V25: the exact "Install eval tools" pip line resolves as a WHOLE, not tool-by-tool. Two
#    independently pinned tools can each work alone yet be mutually impossible together (observed:
#    semgrep==1.127.0 pins tomli~=2.0.1; pip-audit==2.10.1 pins tomli>=2.2.1 — no tomli version
#    satisfies both). This is a static version-range clash, not drift — it fails identically every
#    time regardless of what else is installed, so pip install --dry-run in ANY environment (not
#    necessarily a clean one — that's V23's job, for drift) catches it deterministically. ──
PIP_CMD=()
if command -v pip >/dev/null 2>&1; then PIP_CMD=(pip)
elif command -v pip3 >/dev/null 2>&1; then PIP_CMD=(pip3)
elif command -v python3 >/dev/null 2>&1; then PIP_CMD=(python3 -m pip)
fi
if [ -f "$WF" ] && [ "${#PIP_CMD[@]}" -gt 0 ]; then
  pip_line=$(awk '
    /^      - name: "Install eval tools"/ { instep=1; next }
    instep && /^      - name:/ { instep=0 }
    instep && /^  [a-zA-Z-]+:/ { instep=0 }
    instep && /pip install "/ { print; exit }
  ' "$WF")
  if [ -n "$pip_line" ]; then
    pkgs_arr=()
    while IFS= read -r p; do
      p="${p%\"}"; p="${p#\"}"
      [ -n "$p" ] && pkgs_arr+=("$p")
    done < <(echo "$pip_line" | grep -oE '"[a-zA-Z0-9_.-]+==[a-zA-Z0-9_.-]+"')
    if [ "${#pkgs_arr[@]}" -gt 0 ]; then
      dry_out=$("${PIP_CMD[@]}" install --dry-run "${pkgs_arr[@]}" 2>&1)
      dry_rc=$?
      if [ "$dry_rc" -ne 0 ]; then
        if echo "$dry_out" | grep -qi 'ResolutionImpossible\|conflicting dependencies'; then
          check_fail "the pinned tool set in 'Install eval tools' cannot be resolved together (V25) — pip install --dry-run reports a real conflict:"
          echo "$dry_out" | grep -A6 'conflict is caused by' || echo "$dry_out" | tail -n 10
        elif echo "$dry_out" | grep -qi 'no such option: --dry-run'; then
          note "V25 not run: the local pip ($("${PIP_CMD[@]}" --version 2>/dev/null)) is older than 22.2 and does not support --dry-run. This check WILL run correctly on the actual GitHub Actions runner (actions/setup-python always installs a modern pip) — upgrade local pip to verify it here too."
        else
          note "V25: pip install --dry-run could not complete (network/registry issue, not a version conflict) — re-run with connectivity to verify"
        fi
      else
        check_ok "the pinned tool set in 'Install eval tools' resolves together (V25)"
      fi
    else
      note "V25: no pinned (==) pip packages found in 'Install eval tools' — nothing to dry-run"
    fi
  fi
else
  note "V25 (combined pip resolution) skipped — no pip/pip3/python3 -m pip available in this environment"
fi

# ── V6 (known actions only): marketplace actions actually used carry their required env/permissions ──
if [ -f "$WF" ]; then
  if grep -q 'gitleaks/gitleaks-action' "$WF"; then
    grep -A5 'gitleaks/gitleaks-action' "$WF" | grep -q 'GITHUB_TOKEN' \
      && check_ok "gitleaks-action has GITHUB_TOKEN wired (V6)" \
      || check_fail "gitleaks-action present without GITHUB_TOKEN in its env (V6)"
  fi
  if grep -q 'anthropics/claude-code-action' "$WF"; then
    grep -q 'id-token: write' "$WF" \
      && check_ok "claude-code-action present with id-token: write permission (V6)" \
      || check_fail "claude-code-action present without id-token: write permission (V6)"
  fi
  if grep -qE 'SonarSource/sonarqube-scan-action|SonarSource/sonarqube-quality-gate-action' "$WF"; then
    grep -q 'SONAR_TOKEN' "$WF" && grep -q 'SONAR_HOST_URL' "$WF" \
      && check_ok "SonarQube actions have SONAR_TOKEN/SONAR_HOST_URL wired (V6)" \
      || check_fail "SonarQube action present without both SONAR_TOKEN and SONAR_HOST_URL (V6)"
  fi
fi

# ── V26: CLAUDE_REPAIR_INVOCATION / CLAUDE_JUDGE_INVOCATION must be a RESOLVED claude call (headless +
#    permission flags from `claude --help` at generation time, Section 6.0) — never left as a bare
#    `claude` with no flags. Unresolved, this either hangs on an interactive approval prompt in a
#    TTY-less runner or silently repairs/scores nothing while still looking like it ran — the exact
#    "looks like success" failure Section 6.0 warns about, and V14 does not catch it (its markers live
#    in these SCRIPT files, not in $WF). Observed in practice: self-repair diagnosed the failure
#    correctly, then reported itself blocked from Edit/Write/Bash approval and pushed no fix. ──
check_invocation_resolved() {
  local file="$1" marker="$2"
  [ -f "$file" ] || { note "V26: ${file} not found — skipping (generated separately, or a different variant is in use)"; return; }
  local block
  block="$(awk -v m="$marker" '
    $0 ~ ">>> " m " START <<<" { grabbing=1; next }
    $0 ~ ">>> " m " END <<<" { grabbing=0 }
    grabbing { print }
  ' "$file")"
  if [ -z "$block" ]; then
    check_fail "could not find the ${marker} markers in ${file} — has the fixed template text been hand-edited? (Section 3.1)"
    return
  fi
  if echo "$block" | grep -qE '\bclaude\b' && ! echo "$block" | grep -qE '\bclaude\s+--?[a-zA-Z]'; then
    check_fail "${marker} in ${file} still invokes a bare 'claude' with no flags — headless/permission flags were never resolved at generation time (V26, Section 6.0)"
  else
    check_ok "${marker} in ${file} invokes claude with resolved flags (V26)"
  fi
}
check_invocation_resolved "tests/.evals/scripts/auto-fix-agent.sh" "CLAUDE_REPAIR_INVOCATION"
check_invocation_resolved "tests/.evals/scripts/run-evals.sh" "CLAUDE_JUDGE_INVOCATION"

# ── Slot-equality (Section 3.1): the verify job's ${SETUP_STEPS}+${INSTALL_STEPS} must be
#    byte-identical (mod whitespace) to the self-repair job's ${SELF_REPAIR_SETUP_STEPS} — Section
#    3.1's "must match" rule was previously enforced only by a comment telling the model not to
#    paraphrase, with nothing mechanical checking it.
if [ -f "$WF" ]; then
  v_start=$(grep -n 'do not paraphrase' "$WF" | head -1 | cut -d: -f1 || true)
  v_end=$(grep -n 'Every gate step: id + continue-on-error' "$WF" | head -1 | cut -d: -f1 || true)
  r_start=$(grep -n 'so re-verification after the fix can actually run' "$WF" | head -1 | cut -d: -f1 || true)
  r_end=$(grep -n 'name: "Install Claude Code CLI"' "$WF" | head -1 | cut -d: -f1 || true)

  if [ -z "$v_start" ] || [ -z "$v_end" ] || [ -z "$r_start" ] || [ -z "$r_end" ]; then
    check_fail "could not locate the install-step anchors for the verify/self-repair comparison — has the fixed template text been hand-edited? (Section 3.1)"
  else
    verify_block="$(sed -n "$((v_start+1)),$((v_end-1))p" "$WF")"
    repair_block="$(sed -n "$((r_start+1)),$((r_end-1))p" "$WF")"
    # Strip full-line comments before comparing — explanatory comments are legitimately allowed to
    # differ (or appear only once) as long as the actual commands match; that is the real intent of
    # "must match" (Section 3.1), not byte-identical prose.
    norm_verify="$(printf '%s\n' "$verify_block" | grep -vE '^[[:space:]]*#' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
    norm_repair="$(printf '%s\n' "$repair_block" | grep -vE '^[[:space:]]*#' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
    if [ "$norm_verify" = "$norm_repair" ]; then
      check_ok "verify job and self-repair job install identical setup/tools (Section 3.1)"
    else
      check_fail "verify job and self-repair job install DIFFERENT setup/tools — self-repair would re-verify with a mismatched toolset (Section 3.1)"
      diff <(printf '%s\n' "$norm_verify") <(printf '%s\n' "$norm_repair") | head -n 30
    fi
  fi
fi

# ── V-dryrun: the scripts actually run on the current branch (catches path/flag/mkdir bugs) ──
if [ -n "$BASE_SHA" ] && [ -f "tests/.evals/scripts/run-static-evals.sh" ]; then
  echo "  dry-run: run-static-evals.sh against ${BASE_SHA}"
  bash tests/.evals/scripts/run-static-evals.sh "$BASE_SHA" >/tmp/vp_static.out 2>&1
  drc=$?
  # A real finding (exit 1) is a VALID outcome — it proves the script works. Only a crash-class exit
  # (2) or a missing-dir style error is a validation failure.
  if [ "$drc" -eq 2 ]; then check_fail "run-static-evals crashed (exit 2): $(tail -n3 /tmp/vp_static.out)";
  else check_ok "run-static-evals executed (exit ${drc} — a real finding is a valid outcome)"; fi
else note "dry-run skipped — pass a base sha to enable (recommended before commit)"; fi

note "Not mechanically checked here — verify manually before commit: V3 (every repo script/lockfile the manifest resolved to actually exists — Section 1's own read-never-assume rule), V5 (every secrets.* the workflow references is named in the generation announcement), V17 (the eval.json/judge evidence round trip — needs live judge credentials to exercise), V21 (tool-install retry with an OCI-container fallback, Section 2.4.1)."

echo ""
if [ "$rc" -ne 0 ]; then
  echo "validate-pipeline: FAILED — the pipeline is NOT committed. Fix the findings above and re-run."
else
  echo "validate-pipeline: PASSED — safe to commit."
fi
exit "$rc"
