# smoke-test-epic.ps1 — ONE-TIME, epic-level pre-handoff validation that the generated CI pipeline
# actually works in THIS repo's environment (PowerShell variant of smoke-test-epic.sh).
# See smoke-test-epic.sh for the full contract and what this does/does not validate.
#
# Usage: pwsh smoke-test-epic.ps1 <epic-branch> <epic-id>
# Exit 0 = passed, merged, scratch branch deleted. Exit 1 = exhausted, PR left open. Exit 2 = setup error.
param([string]$EpicBranch = "", [string]$EpicId = "")
$ErrorActionPreference = "Continue"

function Fail($m) { Write-Error "smoke-test-epic: ERROR: $m" }
function NoteMsg($m) { Write-Host "smoke-test-epic: $m" }

if (-not $EpicBranch -or -not $EpicId) { Fail "usage: smoke-test-epic.ps1 <epic-branch> <epic-id>"; exit 2 }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail "gh CLI not installed"; exit 2 }
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Fail "gh CLI not authenticated — run 'gh auth login' first"; exit 2 }

# 🔴 Fixed at 1 (deliberate override) — the smoke test never reads retryLimitForSelfRepair from
#    tests/.evals/config.json for its own budget. This is a smaller, separately-chosen cap for the epic-level
#    environment check specifically, not the real self-repair budget used for actual story-code fixes.
$retryLimit = 1

$slug = ($EpicId -replace '[^A-Za-z0-9._-]', '-')
$scratchBranch = "ci/epic-smoke-$slug"

NoteMsg "cutting scratch branch $scratchBranch from $EpicBranch"
git fetch origin $EpicBranch *> $null
if ($LASTEXITCODE -ne 0) { Fail "could not fetch $EpicBranch from origin"; exit 2 }
# Pushing origin/<epic-branch> straight to refs/heads/<scratch> makes both refs point at the SAME
# commit — GitHub's API then refuses to open a PR ("No commits between ... (createPullRequest)"),
# since head and base are identical. An empty commit (same tree, new commit object) gives the
# scratch branch a distinct SHA — still a genuine zero-diff smoke test, just a real PR is possible.
$env:GIT_COMMITTER_NAME = "aire-ci-smoke"; $env:GIT_COMMITTER_EMAIL = "aire-ci-smoke@localhost"
$env:GIT_AUTHOR_NAME = "aire-ci-smoke"; $env:GIT_AUTHOR_EMAIL = "aire-ci-smoke@localhost"
$smokeSha = git commit-tree "origin/${EpicBranch}^{tree}" -p "origin/${EpicBranch}" `
  -m "chore(ci): zero-diff smoke commit for $EpicId"
Remove-Item Env:\GIT_COMMITTER_NAME, Env:\GIT_COMMITTER_EMAIL, Env:\GIT_AUTHOR_NAME, Env:\GIT_AUTHOR_EMAIL -ErrorAction SilentlyContinue
if (-not $smokeSha) { Fail "could not create the empty smoke-test commit"; exit 2 }
git push origin "${smokeSha}:refs/heads/$scratchBranch" *> $null
if ($LASTEXITCODE -ne 0) { Fail "could not create $scratchBranch on origin from $EpicBranch"; exit 2 }

NoteMsg "opening draft PR: $scratchBranch -> $EpicBranch"
$prUrl = gh pr create --draft --base $EpicBranch --head $scratchBranch `
  --title "[CI-SMOKE] Pre-handoff validation - $EpicId" `
  --body "Automated, zero-diff smoke test of the generated CI pipeline before dev-implement handoff (ci-pipeline-generation.md Section 4.0.6). Safe to ignore - this PR is merged and its scratch branch deleted automatically on a pass, or left open for inspection on failure. Never merge this manually into anything but $EpicBranch."
if ($LASTEXITCODE -ne 0) { Fail "gh pr create failed: $prUrl"; exit 2 }
$prNumber = [regex]::Match($prUrl, '\d+$').Value
NoteMsg "opened $prUrl"

function AbortLeaveOpen {
  Fail "aborting - leaving $prUrl open for inspection, scratch branch $scratchBranch NOT deleted"
}

$runId = $null
$waited = 0
while ($waited -lt 60) {
  $runId = (gh run list --branch $scratchBranch --limit 1 --json databaseId --jq '.[0].databaseId // empty')
  if ($runId) { break }
  Start-Sleep -Seconds 5; $waited += 5
}
if (-not $runId) {
  Fail "no workflow run appeared for $scratchBranch within 60s after opening the PR"
  AbortLeaveOpen
  exit 1
}

$maxAttempts = $retryLimit + 1
$attempt = 1
$passed = $false
while ($attempt -le $maxAttempts) {
  NoteMsg "watching run $runId (attempt $attempt/$maxAttempts)"
  gh run watch $runId --exit-status *> $null
  if ($LASTEXITCODE -eq 0) {
    NoteMsg "run $runId PASSED"
    $passed = $true
    break
  }
  NoteMsg "run $runId FAILED - failed-step logs:"
  $failedLog = gh run view $runId --log-failed 2>&1
  if ($failedLog) { $failedLog | ForEach-Object { Write-Host "  $_" } } else { NoteMsg "(could not fetch failed-step logs for run $runId - inspect $prUrl manually)" }
  NoteMsg "checking whether self-repair pushed a fix"
  $newRunId = $null
  $waited = 0
  while ($waited -lt 120) {
    Start-Sleep -Seconds 10; $waited += 10
    $candidate = (gh run list --branch $scratchBranch --limit 1 --json databaseId --jq '.[0].databaseId // empty')
    if ($candidate -and $candidate -ne $runId) { $newRunId = $candidate; break }
  }
  if (-not $newRunId) {
    NoteMsg "no new run appeared - self-repair did not push a fix, or exhausted its own retries"
    break
  }
  $runId = $newRunId
  $attempt++
}

if ($passed) {
  NoteMsg "merging $prUrl into $EpicBranch and deleting $scratchBranch"
  gh pr merge $prNumber --merge --delete-branch
  if ($LASTEXITCODE -ne 0) { Fail "smoke test passed but the merge failed - resolve $prUrl manually"; exit 1 }
  NoteMsg "smoke test PASSED - $EpicBranch is validated, safe to hand off to dev-implement"
  exit 0
}

$attemptsRun = [Math]::Min($attempt, $maxAttempts)
Fail "SMOKE TEST FAILED after $attemptsRun attempt(s). $prUrl is left OPEN for inspection."
Fail "3 retries ended. Please suggest next steps."
Fail "Development Handoff is BLOCKED until this is resolved - see ci-pipeline-generation.md Section 4.0.6."
exit 1
