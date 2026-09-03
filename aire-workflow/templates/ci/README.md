# CI templates — the static, versioned source the generator COPIES

> These files are the canonical CI pipeline. The AIRE pipeline generator does **not** author YAML or
> shell any more — it **detects the stack, fills the `ci` manifest block in `tests/.evals/config.json`,
> copies these files into the target repo, and substitutes a small fixed set of `${SLOT}` markers.**
> That deletes the whole class of "the model re-wrote a constant and it drifted / broke the parser".
>
> Read `common/ci-pipeline-generation.md` Section 4 for the generation procedure and
> `common/eval-framework.md` Section 1 for the `ci` manifest schema these files read.

## What copies where

| Template | Copied to | Substitution |
|---|---|---|
| `agentic-eval-pipeline.yml.tmpl` | `.github/workflows/agentic-eval-pipeline.yml` | `${SLOT}` markers only |
| `run-static-evals.sh` / `.ps1` | `tests/.evals/scripts/run-static-evals.{sh,ps1}` | none — reads the manifest |
| `run-evals.sh` / `.ps1` | `tests/.evals/scripts/run-evals.{sh,ps1}` | none — reads the manifest |
| `auto-fix-agent.sh` / `.ps1` | `tests/.evals/scripts/auto-fix-agent.{sh,ps1}` | none — reads the manifest |
| `validate-pipeline.sh` / `.ps1` | `tests/.evals/scripts/validate-pipeline.{sh,ps1}` | none — reads the manifest |
| `smoke-test-epic.sh` / `.ps1` | `tests/.evals/scripts/smoke-test-epic.{sh,ps1}` | none — reads the manifest. Run ONCE at the STOP CHECKPOINT (ci-pipeline-generation.md Section 4.0.6), never per story |
| `behavior/run.sh` | `tests/.evals/behavior/run.sh` | none |
| `behavior/Containerfile` | `tests/.evals/behavior/Containerfile` | `${SLOT}` for the base image |
| `sonar-project.properties.tmpl` | `sonar-project.properties` | `${SLOT}` markers only |

Ship the `.sh` variant for POSIX-primary repos and the `.ps1` variant for Windows-primary repos. Pick
by the repo's primary shell; when in doubt ship `.sh` (GitHub-hosted runners are Linux).

## The `${SLOT}` markers in `agentic-eval-pipeline.yml.tmpl`

Only these vary between repos. Everything else is fixed text — never re-authored.

| Slot | Filled from | Example |
|---|---|---|
| `${BASE_BRANCH}` | `ci.baseBranch` | `main` |
| `${PR_BRANCH_FILTERS}` | `ci.integrationBranchPrefixes` → one `- 'prefix/**'` line each | `- 'epic/**'` … |
| `${SETUP_STEPS}` | stack detection (Section 3) — `actions/setup-*` blocks | `uses: actions/setup-python@v5` |
| `${INSTALL_STEPS}` | `ci.installCommands` + `ci.tools` → install + verify blocks | `pip install -r …` |
| `${BUILD_COMMAND}` | Stack's compile/build command (Section 3) — an explicit no-op echo when the stack has none | `cd src/frontend && npm run build` |
| `${COVERAGE_COMMAND}` | `ci.coverageCommand` | `pytest --cov=… --cov-report=xml` |
| `${BEHAVIOR_IMAGE_TAG}` | `tests/.evals/config.json` `behavior.image` | `aire-behavior:ci` |
| `${SONAR_STEPS}` | Section 4.1 — active block, or a commented skip note | see template |
| `${SELF_REPAIR_SETUP_STEPS}` | identical to `${SETUP_STEPS}` + `${INSTALL_STEPS}` | mirrored |
| `${CLAUDE_CODE_VERSION}` | the exact `@anthropic-ai/claude-code` version resolved at generation time (`npm view @anthropic-ai/claude-code version`), the SAME moment `claude --help` is read to resolve the CLAUDE_REPAIR_INVOCATION/CLAUDE_JUDGE_INVOCATION flags (Section 6.0) — never `npm install -g @anthropic-ai/claude-code` unpinned. This package ships multiple releases per DAY; an unpinned install can silently resolve to a different CLI version than the one the flags were verified against, breaking a previously-working invocation with no code change in the repo (ci-pipeline-generation.md Section 6.0.2) | `2.1.258` |

🔴 After substitution, `validate-pipeline.{sh,ps1}` MUST pass before the file is committed. It greps for
any leftover `${` slot, runs `actionlint`, dry-runs the scripts, and asserts every `ci.gates[]` id
appears in both the verdict tally and the `eval.json` schema. A non-zero exit means NOT committed.

## The three script bugs these templates fix permanently

1. **`mkdir -p` precedes every write** — no more `No such file or directory` on a clean CI checkout.
2. **Self-repair never exits 0 on a real failure** — `failed-gates.txt` is the PRIMARY input; a missing
   `eval.json` is a supplementary-input finding, not a free pass.
3. **`EVAL_KEY` handles every integration prefix including `ci/**`** — the resolver reads
   `ci.integrationBranchPrefixes` and fails loudly (never falls through to `unknown`) if the key is
   still unresolved.
