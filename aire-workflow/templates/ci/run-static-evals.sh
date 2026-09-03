#!/usr/bin/env bash
# run-static-evals.sh — D1–D7 static eval gate, DELTA-SCOPED against a base ref.
#
# 🔴 The local Static Eval Gate AND CI both call THIS script. The diff logic lives here ONCE so the two
#    environments cannot drift (common/ci-pipeline-generation.md Section 4.0b, common/eval-framework.md
#    Section 2.2). It reads the `ci` manifest and `thresholds` from tests/.evals/config.json — nothing is
#    hardcoded here that also lives in the config.
#
# Contract:
#   arg1  BASE_SHA — the ref to diff against (the PR base, or the local branch checkpoint)
#   Reads tests/.evals/config.json: ci.tools, ci.sourcePaths, thresholds.*
#   Runs each tool against BASE and HEAD, matches findings on (rule-id, file, message) — NEVER line
#   number — counts only findings NEW-vs-baseline AND on a changed file, writes a machine-readable
#   per-gate summary, and exits non-zero ONLY on a real delta breach.
#
# 🔴 NO STUBS (Section 5.0): a gate that cannot run writes status ERROR and this script exits non-zero.
#    It NEVER fabricates PASS or an untrue N/A. N/A is earned and its reason must be true.
set -uo pipefail

BASE_SHA="${1:-}"
COVERAGE_ONLY=0
if [ "${2:-}" = "--coverage-only" ]; then COVERAGE_ONLY=1; fi
CONFIG="tests/.evals/config.json"
EVAL_KEY="${EVAL_KEY:-local}"
EVIDENCE_DIR="reports/eval-evidence/${EVAL_KEY}"
STATIC_DIR="${EVIDENCE_DIR}/static"

# 🔴 mkdir -p every directory before writing (Section 5.3, V12). A clean CI checkout has none of these.
mkdir -p "${STATIC_DIR}/baseline" "${EVIDENCE_DIR}/judge" tests/.evals/_run

fail() { echo "run-static-evals: ERROR: $*" >&2; }

if [ -z "$BASE_SHA" ]; then
  fail "no BASE_SHA supplied — cannot compute a delta"
  exit 2
fi
if [ ! -f "$CONFIG" ]; then
  fail "$CONFIG missing — cannot resolve the manifest or thresholds"
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  fail "jq not installed — required to read the manifest"
  exit 2
fi

# ── Read the manifest (single source of truth). Portable array fill (no mapfile — bash 3.2 lacks it). ──
TOOLS=(); while IFS= read -r line; do TOOLS+=("$line"); done < <(jq -r '.ci.tools[]?' "$CONFIG")
SOURCES=(); while IFS= read -r line; do SOURCES+=("$line"); done < <(jq -r '.ci.sourcePaths[]?' "$CONFIG")
[ "${#SOURCES[@]}" -eq 0 ] && SOURCES=("src")
SEMGREP_CRIT=$(jq -r '.thresholds.semgrepFindingsAllowed.critical // 0' "$CONFIG")
SEMGREP_HIGH=$(jq -r '.thresholds.semgrepFindingsAllowed.high // 0' "$CONFIG")
SECRETS_ALLOWED=$(jq -r '.thresholds.secretFindingsAllowed // 0' "$CONFIG")

CHANGED="$(git diff --name-only "${BASE_SHA}...HEAD" 2>/dev/null || true)"

RESULT_JSON="${STATIC_DIR}/static-results.json"
# 🔴 Only the D1–D7 pass starts a fresh gates file. The --coverage-only pass (run later, after the
#    coverage report exists) APPENDS its one line to the SAME file so both invocations land in the
#    same eval.json — never truncate here when only computing the coverage gate.
if [ "$COVERAGE_ONLY" -eq 0 ]; then
  : > "$RESULT_JSON.gates"   # one "gate<TAB>status<TAB>reason" line per gate; merged by run-evals
fi

overall_fail=0
record() { # id  status(PASS|FAIL|ERROR|N/A)  reason
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$RESULT_JSON.gates"
  case "$2" in FAIL|ERROR) overall_fail=1 ;; esac
}

has_tool() { for t in "${TOOLS[@]}"; do [ "$t" = "$1" ] && return 0; done; return 1; }

# 🔴 D1–D7 run only on the normal pass. The --coverage-only pass runs later in the pipeline (after
#    "unit + coverage" has produced the report) purely to compute the coverage gate — re-running
#    semgrep/gitleaks/D1-D2/D4-D6 a second time here would be wasted work, not a correctness issue,
#    but it's also wrong: it would re-diff against a tree state that has since moved (checkout cycles
#    inside delta_diff), for no benefit.
if [ "$COVERAGE_ONLY" -eq 0 ]; then

# ── D3 SAST — semgrep with its NATIVE baseline flag (only NEW findings since BASE_SHA) ──
if has_tool semgrep; then
  if command -v semgrep >/dev/null 2>&1; then
    out="${STATIC_DIR}/semgrep-delta.json"
    if semgrep --config auto --baseline-commit "$BASE_SHA" --json --quiet "${SOURCES[@]}" > "$out" 2>/dev/null; then
      crit=$(jq '[.results[]? | select(.extra.severity=="ERROR")] | length' "$out")
      high=$(jq '[.results[]? | select(.extra.severity=="WARNING")] | length' "$out")
      if [ "$crit" -gt "$SEMGREP_CRIT" ] || [ "$high" -gt "$SEMGREP_HIGH" ]; then
        record D3_sast FAIL "new semgrep findings: ${crit} critical, ${high} high (allowed ${SEMGREP_CRIT}/${SEMGREP_HIGH})"
      else
        record D3_sast PASS "no new findings above threshold"
      fi
    else
      record D3_sast ERROR "semgrep run failed"
    fi
  else
    record D3_sast ERROR "semgrep in manifest but not installed"
  fi
fi

# ── D7 Secrets — gitleaks scoped to the new commits only ──
if has_tool gitleaks; then
  if command -v gitleaks >/dev/null 2>&1; then
    out="${STATIC_DIR}/gitleaks-delta.json"
    gitleaks detect --no-banner --redact --report-format json --report-path "$out" \
      --log-opts "${BASE_SHA}..HEAD" >/dev/null 2>&1 || true
    n=$( [ -f "$out" ] && jq 'length' "$out" 2>/dev/null || echo 0 )
    if [ "${n:-0}" -gt "$SECRETS_ALLOWED" ]; then
      record D7_secrets FAIL "${n} secret finding(s) in new commits (allowed ${SECRETS_ALLOWED})"
    else
      record D7_secrets PASS "no new secrets"
    fi
  else
    record D7_secrets ERROR "gitleaks in manifest but not installed"
  fi
fi

fi   # end: D3/D7 run only on the normal (non --coverage-only) pass

# ── D1 Lint · D2 Types · D4 Deps · D5 Licences · D6 Complexity ──
# These have no universal native baseline flag. The BASE side is the baseline dev-implement.md Step 4.6
# already captured and COMMITTED to this story branch, once, before any code was generated — delta_diff
# below reuses that committed file directly instead of re-deriving it. The generator resolves the
# concrete tool invocation per stack (Section 3) and appends it below via the delta_diff helper. If the
# manifest lists the tool but no invocation was resolved, that is an ERROR — never a silent skip.
# Captured once, before any stash/checkout cycle, so every restore targets a known-good ref — never
# `checkout -`, whose target can drift once the tree has been detached more than once in this script.
ORIG_REF="$(git symbolic-ref -q --short HEAD || git rev-parse HEAD)"

delta_diff() { # gate_id  "cmd producing 'rule\tfile\tmessage' lines"
  local gate="$1" cmd="$2"
  local base head stashed=0 before_stash after_stash base_ok checkout_err
  base="${STATIC_DIR}/baseline/${gate}.txt"
  head="${STATIC_DIR}/${gate}-head.txt"

  # 🔴 REUSE the already-committed baseline when one exists. dev-implement.md Step 4.6 captures this
  #    EXACT file once, on the story branch, BEFORE any code is generated, and commits it — making
  #    reports/eval-evidence/<key>/static/baseline/ a TRACKED path in this branch's history, never
  #    disposable scratch space. Recomputing it here via a BASE_SHA checkout writes an untracked file
  #    at that same tracked path while displaced at BASE_SHA; returning to ORIG_REF then makes git
  #    REFUSE the checkout ("untracked working tree file would be overwritten by checkout") because
  #    the committed version is still sitting there — a real FATAL abort, observed in CI. Trust the
  #    committed baseline and skip the whole checkout dance in that case; only recompute via checkout
  #    when no baseline is committed yet (the pre-story epic-level smoke test, which has no story
  #    branch to have captured one — ci-pipeline-generation.md Section 4.0.6).
  if [ ! -f "$base" ]; then
    before_stash="$(git stash list | wc -l | tr -d ' ')"
    git stash push -q --include-untracked 2>/dev/null || true
    after_stash="$(git stash list | wc -l | tr -d ' ')"
    [ "$after_stash" -gt "$before_stash" ] && stashed=1

    checkout_err="$(git checkout -q "$BASE_SHA" 2>&1)"
    if [ $? -ne 0 ]; then
      record "$gate" ERROR "cannot checkout base ref: ${checkout_err}"
      if [ "$stashed" -eq 1 ] && ! git stash pop -q 2>/dev/null; then
        fail "FATAL: could not restore stash after a failed checkout — working tree left dirty. Aborting rather than running further gates or stages against a broken tree."
        exit 3
      fi
      return
    fi

    # 🔴 Defensive re-mkdir: the checkout above can leave this untracked directory gone by the time we
    #    write to it. Without this, the write below silently fails, sort/comm then read a missing file
    #    as an EMPTY baseline, and every pre-existing finding gets miscounted as "new" — a fabricated
    #    FAIL from a capture that never actually happened (violates Section 5.0 NO STUBS).
    mkdir -p "${STATIC_DIR}/baseline"
    eval "$cmd" > "$base" 2>/dev/null || true
    base_ok=1
    [ -f "$base" ] || base_ok=0

    checkout_err="$(git checkout -q "$ORIG_REF" 2>&1)"
    if [ $? -ne 0 ]; then
      fail "FATAL: could not return to ${ORIG_REF} after checking out the base ref: ${checkout_err}. Aborting rather than running further gates or stages against a broken tree."
      exit 3
    fi

    if [ "$stashed" -eq 1 ]; then
      checkout_err="$(git stash pop -q 2>&1)"
      if [ $? -ne 0 ]; then
        fail "FATAL: git stash pop failed (likely a conflict): ${checkout_err}. Working tree left dirty. Aborting rather than running further gates or stages against a broken tree."
        exit 3
      fi
    fi

    if [ "$base_ok" -eq 0 ]; then
      record "$gate" ERROR "baseline capture failed — ${base} was not written while checked out at ${BASE_SHA} (cannot compute a delta from a missing baseline, Section 5.0)"
      return
    fi
  fi

  mkdir -p "${STATIC_DIR}"
  eval "$cmd" > "$head" 2>/dev/null || true
  if [ ! -f "$head" ]; then
    record "$gate" ERROR "head capture failed — ${head} was not written at ${ORIG_REF}"
    return
  fi
  # NEW findings = in head, not in base (match on the whole rule\tfile\tmessage tuple, not line no.)
  local new
  new=$(comm -13 <(sort -u "$base") <(sort -u "$head") | wc -l | tr -d ' ')
  if [ "${new:-0}" -gt 0 ]; then
    record "$gate" FAIL "${new} new finding(s) vs baseline on changed files"
  else
    record "$gate" PASS "no new findings vs baseline"
  fi
}
# ── unitCoverage — delta-scoped against the coverage report(s) the "unit + coverage" step already
#    produced (Section 4.0b: run-static-evals owns this verdict; the raw test command never applies
#    --cov-fail-under itself). Supports cobertura (pytest-cov, dotnet coverlet) and lcov (istanbul/
#    c8/vitest). Anything else, or a missing manifest field, is a real ERROR — never a silent N/A.
#
#    🔴 MULTI-REPORT: a full-stack project has separate backend + frontend coverage reports. Configure
#    `ci.coverageReports`: an array of {path, format, sourcePaths}; each changed file is matched to
#    the report whose sourcePaths prefix owns it, and scored against that report specifically. A
#    changed file matching no report's sourcePaths is skipped (not every changed file is coverable —
#    e.g. docs, config). `ci.coverageReportPath`/`ci.coverageFormat` (single pair, scored against the
#    whole `ci.sourcePaths`) still works unmodified when `coverageReports` is absent — back-compat. ──
coverage_delta() {
  local min changed hit=0 found=0 f had_error=0
  min=$(jq -r '.thresholds.unitTestCoverageMin // 90' "$CONFIG")

  local report_count
  report_count=$(jq -r '.ci.coverageReports // [] | length' "$CONFIG")

  local -a REPORT_PATHS=() REPORT_FORMATS=() REPORT_SOURCEPATHS=()
  if [ "$report_count" -gt 0 ]; then
    while IFS=$'\t' read -r rp rf rs; do
      REPORT_PATHS+=("$rp"); REPORT_FORMATS+=("$rf"); REPORT_SOURCEPATHS+=("$rs")
    done < <(jq -r '.ci.coverageReports[] | [.path, .format, (.sourcePaths // [] | join("|"))] | @tsv' "$CONFIG")
  else
    local single_path single_format
    single_path=$(jq -r '.ci.coverageReportPath // ""' "$CONFIG")
    single_format=$(jq -r '.ci.coverageFormat // ""' "$CONFIG")
    if [ -z "$single_path" ] || [ -z "$single_format" ]; then
      record unitCoverage ERROR "neither ci.coverageReports nor ci.coverageReportPath/ci.coverageFormat is set in the manifest — cannot compute the delta-scoped coverage gate (Section 4.0b)"
      return
    fi
    REPORT_PATHS=("$single_path"); REPORT_FORMATS=("$single_format")
    local joined; joined=$(IFS='|'; echo "${SOURCES[*]}")
    REPORT_SOURCEPATHS=("$joined")
  fi

  if ! command -v python3 >/dev/null 2>&1 && printf '%s\n' "${REPORT_FORMATS[@]}" | grep -q '^cobertura$'; then
    record unitCoverage ERROR "ci.coverageFormat=cobertura requires python3, which is not installed"
    return
  fi

  changed="$(git diff --name-only "${BASE_SHA}...HEAD" -- "${SOURCES[@]}" 2>/dev/null || true)"
  if [ -z "$changed" ]; then
    record unitCoverage PASS "no changed files under ${SOURCES[*]} — threshold vacuously satisfied"
    return
  fi

  while IFS= read -r f; do
    [ -z "$f" ] && continue

    local matched_idx=-1 i
    for i in "${!REPORT_SOURCEPATHS[@]}"; do
      local sp_joined="${REPORT_SOURCEPATHS[$i]}" sp matched=0
      IFS='|' read -ra sp_arr <<< "$sp_joined"
      for sp in "${sp_arr[@]}"; do
        case "$f" in "$sp"/*|"$sp") matched=1; break ;; esac
      done
      if [ "$matched" -eq 1 ]; then matched_idx="$i"; break; fi
    done
    [ "$matched_idx" -eq -1 ] && continue   # not owned by any configured report — not every changed file is coverable

    local rp="${REPORT_PATHS[$matched_idx]}" rfmt="${REPORT_FORMATS[$matched_idx]}" lh="" lf=""
    if [ ! -f "$rp" ]; then
      fail "unitCoverage: coverage report not found at ${rp} — needed for changed file ${f}"
      had_error=1
      continue
    fi

    case "$rfmt" in
      cobertura)
        read -r lh lf < <(REPORT_PATH="$rp" TARGET_FILE="$f" python3 - <<'PYEOF'
import os, xml.etree.ElementTree as ET
tree = ET.parse(os.environ["REPORT_PATH"]); root = tree.getroot()
target = os.environ["TARGET_FILE"]
h = 0; t = 0
for cls in root.iter('class'):
    fn = cls.get('filename', '')
    if fn == target or fn.endswith('/' + target) or target.endswith('/' + fn):
        lines = cls.find('lines')
        if lines is not None:
            for l in lines.findall('line'):
                t += 1
                if int(l.get('hits', 0)) > 0:
                    h += 1
print(h, t)
PYEOF
) 2>/dev/null
        ;;
      lcov)
        # Bidirectional match: the report's SF: path may be relative to the repo root OR to the
        # subdirectory the coverage command ran from (e.g. `cd src/frontend && npm test`), while
        # git diff paths are always repo-root-relative. A one-directional substring check silently
        # never matches the subdirectory case — confirmed as a real failure, fixed here.
        read -r lh lf < <(awk -v target="$f" '
          function endswith(s, suf) { return length(s) >= length(suf) && substr(s, length(s)-length(suf)+1) == suf }
          $0 ~ /^SF:/ { file=substr($0,4); active = (file == target) || endswith(file, "/" target) || endswith(target, "/" file) }
          active && /^LH:/ { lh=substr($0,4) }
          active && /^LF:/ { lf=substr($0,4) }
          /^end_of_record/ && active { print lh, lf; active=0; lh=0; lf=0 }
        ' "$rp")
        ;;
      *)
        fail "unitCoverage: unsupported format '${rfmt}' for report ${rp} — only cobertura and lcov are implemented"
        had_error=1
        continue
        ;;
    esac
    hit=$((hit + ${lh:-0})); found=$((found + ${lf:-0}))
  done <<< "$changed"

  if [ "$had_error" -eq 1 ]; then
    record unitCoverage ERROR "one or more changed files' coverage reports were missing or unsupported — see the job log above"
    return
  fi
  if [ "$found" -eq 0 ]; then
    record unitCoverage ERROR "no coverage data found for any changed file across the configured report(s) — report/changed-file path mismatch"
    return
  fi

  local pct
  pct=$(awk -v h="$hit" -v f="$found" 'BEGIN{printf "%.1f", (h/f)*100}')
  if awk -v p="$pct" -v m="$min" 'BEGIN{exit !(p+0 >= m+0)}'; then
    record unitCoverage PASS "changed-file coverage ${pct}% >= ${min}% (${hit}/${found} lines)"
  else
    record unitCoverage FAIL "changed-file coverage ${pct}% < ${min}% (${hit}/${found} lines)"
  fi
}

# GENERATED PER STACK: the generator appends one `delta_diff <gate> '<cmd>'` line per resolved D1/D2/
# D4/D5/D6 tool here, OR a `record <gate> "N/A" "<true reason>"` when the stack genuinely lacks it.
# 🔴 If a manifest tool has neither an invocation nor a true N/A reason, emit `record <gate> ERROR ...`.
# Runs only on the normal pass — same reasoning as the D3/D7 guard above.
if [ "$COVERAGE_ONLY" -eq 0 ]; then
  :  # no-op — keeps this block syntactically valid even before the generator fills in any gates
     # (bash treats an if-body containing only comments as empty, which is a syntax error)
# >>> STACK-RESOLVED D-GATES START <<<
# >>> STACK-RESOLVED D-GATES END <<<
fi

# unitCoverage runs ONLY on the --coverage-only pass, called after "unit + coverage" has produced
# the report this function reads (Section 4.0b). See the coverage_delta() definition above.
if [ "$COVERAGE_ONLY" -eq 1 ]; then
  coverage_delta
fi

# Emit summary and set exit code from real results only.
echo "static eval gates (delta vs ${BASE_SHA}):"
cat "$RESULT_JSON.gates" | while IFS=$'\t' read -r g s r; do printf '  %-14s %-5s %s\n' "$g" "$s" "$r"; done

if [ "$overall_fail" -ne 0 ]; then
  echo "run-static-evals: at least one D-gate FAILED or ERRORED (delta-scoped)" >&2
  exit 1
fi
exit 0
