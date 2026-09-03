# auto-fix-agent.ps1 — CI self-repair via the Claude Code CLI (PowerShell variant of auto-fix-agent.sh).
# 🔴 PRIMARY input = tests/.evals/_run/failed-gates.txt. Missing => PIPELINE DEFECT, exit NON-ZERO (never exit 0
#    on an unrepaired job). eval.json is SUPPLEMENTARY. mkdir before the counter write (rule 2).
$ErrorActionPreference = "Continue"

$config = "tests/.evals/config.json"
$runDir = "tests/.evals/_run"
$failedGates = "$runDir/failed-gates.txt"
$baseSha = $env:BASE_SHA
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function ReportAndExit($m, $code = 1) { Write-Error "auto-fix-agent: $m"; exit $code }

if (-not (Test-Path $failedGates)) {
  ReportAndExit "PIPELINE DEFECT: $failedGates missing — the Verdict step must always produce it. Not exiting 0 on an unrepaired failure." 1
}
$gates = @(Get-Content $failedGates | Where-Object { $_.Trim() -ne "" })
if ($gates.Count -eq 0) { ReportAndExit "failed-gates.txt empty but self-repair triggered — cannot determine what to repair." 1 }

$limit = 3
if ((Test-Path $config) -and (Get-Command jq -ErrorAction SilentlyContinue)) { $limit = [int](jq -r '.retryLimitForSelfRepair // 3' $config) }
$counter = "$runDir/self-repair-attempt"
$prev = if (Test-Path $counter) { [int](Get-Content $counter -Raw) } else { 0 }
$attempt = $prev + 1
if ($attempt -gt $limit) { ReportAndExit "retry limit $limit reached — 3 retries ended. Please suggest next steps. Unresolved: $($gates -join ', ')" 1 }
$attempt | Out-File -Encoding utf8 $counter

foreach ($g in $gates) {
  if ($g -eq "sonar") {
    $cond = "$runDir/sonar-conditions.txt"
    if (-not ((Test-Path $cond) -and (Get-Item $cond).Length -gt 0)) {
      ReportAndExit "sonar failed WITHOUT reported conditions (auth/unreachable/timeout) — infrastructure, not a code defect. Not consuming a retry." 1
    }
  }
}

$evalJson = Get-ChildItem -Recurse -Filter eval.json -Path "reports/eval-evidence" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $evalJson) { Write-Error "auto-fix-agent: note — no eval.json found; repairing from failed-gates.txt + logs (Section 6.5)." }

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { ReportAndExit "claude CLI not installed — cannot self-repair." 1 }

# 🔴 The BRIEF below tells Claude to commit its own fix (it has git tool access) — so "did the agent
#    change anything" can NOT be judged by working-tree dirtiness alone: a clean `git status` after
#    the CLI call means "Claude already committed it", not "nothing happened". Track HEAD movement too.
$beforeSha = (git rev-parse HEAD)

$brief = @"
The agentic eval pipeline failed on this PR.
Failed gates: $($gates -join ', ')
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
Commit with:  fix(ci): self-repair attempt $attempt — $($gates -join ', ')
"@

# >>> CLAUDE_REPAIR_INVOCATION START <<<
$brief | claude
if ($LASTEXITCODE -ne 0) { ReportAndExit "the repair CLI invocation failed on attempt $attempt." 1 }
# >>> CLAUDE_REPAIR_INVOCATION END <<<

# Claude may have committed the fix itself (per the BRIEF) — that leaves the tree clean but HEAD
# moved. Only a clean tree AND an unmoved HEAD means it genuinely made no changes.
$afterSha = (git rev-parse HEAD)
if ($afterSha -eq $beforeSha -and -not (git status --porcelain)) { ReportAndExit "self-repair produced no changes on attempt $attempt — PR stays red." 1 }

# 🔴 D7_secrets is the ONE gate a forward commit can be structurally unable to clear: gitleaks scans
#    --log-opts BASE..HEAD, i.e. every commit's OWN patch in that range — not the final tree. A finding
#    anchored to a commit already pushed to origin before this attempt started stays in that history
#    forever. Refusing to commit in that case would discard real, valuable fixes for no benefit — but
#    silently committing as if D7 passed would hide a genuinely unresolved finding. Do neither.
function D7OnlyHistoryAnchoredRemaining {
  $gatesFile = Get-ChildItem -Recurse -Filter "static-results.json.gates" -Path "reports/eval-evidence" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $gatesFile) { return $false }
  $failing = @()
  foreach ($line in (Get-Content $gatesFile.FullName)) {
    $parts = $line -split "`t"
    if ($parts.Count -ge 2 -and ($parts[1] -eq "FAIL" -or $parts[1] -eq "ERROR")) { $failing += $parts[0] }
  }
  # Must be the ONLY thing still failing — anything else means real fixable work remains.
  if ($failing.Count -ne 1 -or $failing[0] -ne "D7_secrets") { return $false }

  $gitleaksReport = Get-ChildItem -Recurse -Filter "gitleaks-delta.json" -Path "reports/eval-evidence" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $gitleaksReport -or -not (Get-Command jq -ErrorAction SilentlyContinue)) { return $false }

  $headRef = if ($env:GITHUB_HEAD_REF) { $env:GITHUB_HEAD_REF } else { "main" }
  $originRef = "origin/$headRef"
  git fetch origin $headRef 2>$null | Out-Null

  $commits = @(jq -r '.[].Commit // empty' $gitleaksReport.FullName 2>$null | Sort-Object -Unique)
  foreach ($commit in $commits) {
    if (-not $commit) { continue }
    git merge-base --is-ancestor $commit $originRef 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
  }
  return $true
}

if ($baseSha) {
  bash tests/.evals/scripts/run-static-evals.sh $baseSha 2>$null
  $staticRc = $LASTEXITCODE
  bash tests/.evals/scripts/run-evals.sh $baseSha 2>$null
  $evalsRc = $LASTEXITCODE
  if ($staticRc -ne 0 -or $evalsRc -ne 0) {
    if (D7OnlyHistoryAnchoredRemaining) {
      Write-Host "auto-fix-agent: D7_secrets remains red - every remaining finding is anchored to an already-pushed commit (gitleaks' own --log-opts BASE..HEAD commit-range scan); no forward commit can clear it. Proceeding to commit the real fix(es) made for the other gate(s). D7_secrets needs a human decision: rebase to scrub the secret from that commit and force-push, or (only if it is a rotated/false-positive credential) add a scoped gitleaks allowlist entry for that exact fingerprint - never a blanket suppression."
    } else {
      ReportAndExit "re-verification still FAILS after repair attempt $attempt — not committing an unverified fix." 1
    }
  }
}

# 🔴 A fresh GH Actions runner has no git identity configured — git commit fails outright even after
#    a fully correct repair, wasting a retry on something that was never a code problem. --local scopes
#    it to this checkout only. Same bot-identity convention as smoke-test-epic.sh's aire-ci-smoke commits.
git config --local user.name "aire-self-repair"
git config --local user.email "aire-self-repair@localhost"

# Claude may have already committed its own fix inside the CLI call above. Only create an extra
# commit for whatever it left uncommitted — never treat "nothing left to stage" as a failure.
if (git status --porcelain) {
  git add -A
  git commit -m "fix(ci): self-repair attempt $attempt — $($gates -join ', ')"
  if ($LASTEXITCODE -ne 0) { ReportAndExit "commit failed on attempt $attempt." 1 }
}
$head = if ($env:GITHUB_HEAD_REF) { $env:GITHUB_HEAD_REF } else { "HEAD" }
git push origin "HEAD:$head"
if ($LASTEXITCODE -ne 0) { ReportAndExit "push failed on attempt $attempt." 1 }

Write-Output "auto-fix-agent: attempt $attempt committed and pushed for gates: $($gates -join ', ')"
exit 0
