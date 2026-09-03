# HELIX AIRE

**HELIX AIRE** is an adaptive, AI-driven software development workflow framework. It takes you from a **product idea → a refined Epic → requirements → a finished, reviewed product** — with a human approval at planning stage and a complete audit trail. Works with **Jira, Azure DevOps, GitHub Issues, or fully local** (no external tracker at all).

---

## Table of Contents

1. [How It Works — The Big Picture](#how-it-works--the-big-picture)
2. [Prerequisites](#prerequisites)
3. [CI/CD Eval Pipeline — secrets and setup](#cicd-eval-pipeline--secrets-and-setup)
4. [Usage](#usage)
5. [Context Project — feeding curated context](#context-project)
6. [New References — reference materials for new work](#new-references)
7. [Resumable Sessions](#resumable-sessions)
8. [The End-to-End Journey](#the-end-to-end-journey)
9. [The Bug-Fix Journey](#the-bug-fix-journey)
10. [The Enhancement Journey](#the-enhancement-journey)
11. [Verification Engineer Operating Guide](#verification-engineer-operating-guide)
12. [Dependency Graph](#dependency-graph)
13. [Keyword Workflows](#keyword-workflows)
14. [Claude Code Skills](#claude-code-skills)
15. [Framework Distribution — auto-install & auto-update AIRE in any repo](#framework-distribution--auto-install--auto-update-aire-in-any-repo)
16. [Agents](#agents)

---

## How It Works — The Big Picture

```
                         YOUR RAW PRODUCT IDEA
                                   │
                                   ▼
        Sourcing the epic from Atlas via a connected Helix
       MCP server? Skip intent-intake and intent-refinement
     and go straight to "Using AIRE, <epic-reference>" below.
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────┐
  │ SKILL: intent-intake                                    │
  │                                                         │
  │ Captures the idea as a lightweight intent (outcome,     │
  │ KPI, success signal, out-of-scope, constraints) and     │
  │ pushes it to your tracker: Jira, Azure DevOps,          │
  │ GitHub, or keeps it local.                              │
  └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
       OUTPUT: an Epic on your tracker (baseline). Example:
         a Jira key, an ADO work item, or a GitHub issue.
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────┐
  │ SKILL: intent-refinement                                │
  │                                                         │
  │ Elaborates the Epic with engineers: measurable          │
  │ success criteria, scope, constraints, domain            │
  │ model, NFRs, and risks.                                 │
  └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          OUTPUT: the same Epic, updated on your tracker,
                now fully detailed and verifiable.
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────┐
  │ IN CLAUDE CODE, IN YOUR PROJECT, TYPE:                  │
  │                                                         │
  │ Using AIRE, <epic-reference>                            │
  │                                                         │
  │ A Jira, Azure DevOps, or GitHub link. A plain           │
  │ description for a local-only project. Or, for an        │
  │ epic already in Atlas: "implement the solution          │
  │ epic from Helix, via Helix MCP."                        │
  └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────┐
  │ AIRE LIFECYCLE                                          │
  │                                                         │
  │ PLANNING, then IMPLEMENTATION                           │
  │                                                         │
  │ SUPPORTING SKILLS                                       │
  │ story-audit, ve-implement, code-security-review,        │
  │ raise-defect, pr-generator, pr-review, ve-list-work,    │
  │ reverse-engineering-root, archive-epic                  │
  └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                    FINISHED, REVIEWED PRODUCT
```

Four moving parts:

| Part | Where | What it does |
|------|-------|--------------|
| **`CLAUDE.md`** | project root | The master workflow. Claude Code reads it automatically and it orchestrates every phase, gate, and approval. Kept deliberately thin — detail lives in the rulebook. |
| **`aire-workflow/`** | project root | The detailed rulebook: step-by-step instructions for every stage, keyword workflow, agent, and extension, plus `aire-workflow-diagram.md` (the end-to-end flow diagrams). Loaded on demand to save context. |
| **`spec/` + `tests/.evals/`** | project root | What the agent builds against, and what it is judged by. `spec/` holds the per-work-unit specification bundles and all documentation; `tests/.evals/` holds the thresholds, the derived rubrics, and the CI eval runners. |
| **`.claude/skills/`** | project root | Standalone Claude Code skills (intent intake/refinement, story/epic audit, ve build-and-test, PR generator/review, defect raising, ve sign-off, security review, reverse engineering, archiving) that plug into the lifecycle before, during, and after development. |

### Which issue tracker do I use?

HELIX AIRE supports four interchangeable trackers, and asks you to pick **once per
epic**, right at the start:

| Tracker | Epics/stories pushed via | Prerequisite |
|---------|--------------------------|---------------|
| **Jira** | the Atlassian MCP server | Prerequisite #3 below |
| **Azure DevOps (ADO)** | the `az boards` CLI | Prerequisite #5 below |
| **GitHub** | the `gh` CLI | Prerequisite #2 below |
| **Local only** | nothing external — everything lives in `runtime-artifacts/aire-state.md` in your repo | none |

Whichever you choose, the rest of the framework behaves identically — stories, statuses, PR labels,
and the `ai-generated`/`aire-v[N]` tags all dispatch on your choice automatically. The examples
throughout this README use Jira for illustration; substitute your own tracker's ID/URL format (an
ADO work item, a GitHub issue, or nothing at all for Local) wherever you see a Jira example.

The workflow is **adaptive**: the AI assesses your request, your workspace (greenfield vs. brownfield), and the complexity/risk of the change, then runs only the stages that add value — at minimal, standard, or comprehensive depth. You stay in control where it matters: the **Planning-phase and design stages require your explicit
approval**, and every interaction is logged verbatim in an audit trail. Implementation itself is
deliberately hands-off — naming a story is the only input `dev-implement` needs — but it is bounded:
**every automatic self-healing loop stops after 3 attempts**, then halts and asks you for next steps
rather than pushing past a failing gate.

> ℹ **Already have Atlas connected?** If your repository's existing-system knowledge already lives
> in **Atlas** and is reachable through a connected **Helix MCP** server, AIRE pulls that context
> directly — so you can skip `intent-intake` / `intent-refinement` for an Epic that's already backed
> by Atlas, and go straight to `Using AIRE, implement the epic from Helix`. This is independent of
> which issue tracker you use — Jira, Azure DevOps, GitHub, or fully local — see the Helix MCP
> prerequisite below.

---


## Prerequisites

Install and configure the following **before** using the framework into your project:

#### 1. Claude Code

The framework runs entirely inside Claude Code (CLI, desktop app, or IDE extension).

#### 2. GitHub CLI (`gh`)

Used to raise, review, and check the merge state of Pull Requests.

```bash
# macOS
brew install gh

# Windows
winget install --id GitHub.cli

# Linux (Debian/Ubuntu)
sudo apt install gh
```

- Full install doc: <https://github.com/cli/cli#installation>
- **Authenticate after installing**: `gh auth login` (choose GitHub.com → HTTPS → login via browser).
- Verify: `gh auth status` should show you as logged in with `repo` access.

#### 3. Atlassian (Jira) MCP connection

The framework talks to Jira through the **Atlassian MCP server** 

**Claude Code**

Run the following command:

```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp/authv2
```

Then, inside a Claude Code session, run `/mcp` and complete the OAuth login to your Atlassian site.

**Claude Desktop**

1. Open **Claude Desktop**.
2. Go to **Settings → Extensions**.
3. Select **Browse extensions**, then select **Plugins**.
4. Search for **Atlassian** and install it.

- Atlassian's official server: <https://support.atlassian.com/atlassian-rovo-mcp-server/docs/getting-started-with-the-atlassian-remote-mcp-server/>
- Claude Code MCP setup docs: <https://docs.anthropic.com/en/docs/claude-code/mcp>
- Verify: in a Claude Code session, by running `/mcp`

#### 4. Disable Claude Code's built-in `code-review` skill

Turn **off** Claude Code's built-in `code-review` skill.

1. Open your **user-profile** settings file: `~/.claude/settings.json` (Eg: on Windows: `C:\Users\<you>\.claude\settings.json`).
2. Add the following top-level key (merge it into the existing JSON):

```json
"skillOverrides": {
    "code-review": "off"
}
```

3. Save the file and restart Claude Code so the override takes effect.

#### 5. Azure CLI (only if your issue tracker is Azure DevOps)

If you selected **ADO** as your issue tracker, the agent drives Azure DevOps through the `az` CLI. You must install it once on your machine.

➡ Download / install: <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli>

After install, add the DevOps extension and authenticate:

```bash
# Install the Azure DevOps extension
az extension add --name azure-devops

# Log in with your Azure / Entra ID account
az login
```

`az login` opens a browser window. The session stays active until you run `az logout`. This is a one-time setup per machine.

#### 6. Podman CLI and Podman Desktop

Helix AIRE's local evaluation gates run the Gherkin behavioural tests inside a container for parity between local runs and CI for that Podman is configured, so it must be installed and running.

➡ Download / install Podman Desktop (includes the `podman` CLI and manages the Podman machine/VM for you): <https://podman-desktop.io/downloads>

Alternatively, install just the CLI:

```bash
# macOS
brew install podman

# Windows
winget install -e --id RedHat.Podman

# Linux (Debian/Ubuntu)
sudo apt install podman
```

After install (macOS/Windows only — Linux runs Podman natively), initialize and start the Podman machine once:

```bash
podman machine init
podman machine start
```

Verify: `podman info` should return without error.

> If Podman is unavailable at eval time, the behavioural tests wont run.

#### 7. Helix MCP connection (recommended)

Connect the **Helix MCP** server to your Claude Code setup once per repository. AIRE detects it
automatically the first time it's needed, and pulls existing-system truth — knowledge graph and
deepdive docs, epic plan — straight from Atlas instead of re-deriving it from scratch.

---

## CI/CD Eval Pipeline — required secrets setup 

AIRE generates a CI/CD eval pipeline (`.github/workflows/agentic-eval-pipeline.yml`) tailored to your project. The pipeline re-runs the same gates locally enforced during development — static analysis , unit tests, Gherkin behavioural tests, regression, and LLM-as-judge scoring (architecture conformance, OWASP security) — plus an autonomous self-repair job that uses Claude Code CLI to fix failing gates automatically.

The pipeline itself, the eval scripts, and all configuration are generated for you at the STOP CHECKPOINT (after the design stages). Three secrets cannot be generated because they belong to your accounts. Everything else works without them — the gates still run and still block the PR. Only the self-repair job and the SonarQube scan are skipped when their secrets are absent.

### Secrets overview

| Secret | Purpose | Required? |
|--------|---------|-----------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Lets the pipeline fix its own failing gates and run the J1/J2 judge scoring via Claude Code CLI | No — gates still run and block. Only self-repair and judge scoring are skipped. |
| `SONAR_TOKEN` | Authenticates to SonarQube (Cloud or self-hosted) for the D3 static security gate | No — semgrep and the 16-rule Security Baseline review still run. SonarQube is additive. |
| `SONAR_HOST_URL` | Address of your SonarQube server | No — only needed alongside `SONAR_TOKEN`. |
| `GITHUB_TOKEN` | Used by the secret scanner (gitleaks) | Auto-provided by GitHub Actions. Nothing to do. |

### How to get `CLAUDE_CODE_OAUTH_TOKEN`

1. Install Claude Code if you do not already have it:

   ```bash
   npm install -g @anthropic-ai/claude-code
   ```

2. Sign in once, interactively:

   ```bash
   claude
   ```

   Complete the browser prompt, then leave with `/exit`.

3. Generate a long-lived token for CI:

   ```bash
   claude setup-token
   ```

4. Copy the value it prints. It is shown once and cannot be retrieved later.

5. **Alternative — API key instead of OAuth token**: create one at <https://console.anthropic.com> under **API Keys**, and name the secret `ANTHROPIC_API_KEY` instead of `CLAUDE_CODE_OAUTH_TOKEN`. The pipeline accepts either.

### How to get `SONAR_TOKEN` and `SONAR_HOST_URL`

**Option A — SonarQube Cloud** (hosted by Sonar, free for public repositories):

1. Open <https://sonarcloud.io> and sign in with your GitHub account.
2. Select **Analyze new project** and choose this repository.
3. Go to **My Account** then **Security**.
4. Enter a token name and select **Generate**. Copy the token value — it is shown once.
5. Your `SONAR_HOST_URL` is `https://sonarcloud.io`.

**Option B — SonarQube Community Build** (free, self-hosted):

1. Start the server:

   ```bash
   podman run -d --name sonarqube -p 9000:9000 docker.io/sonarqube:community
   ```

2. Wait about 90 seconds, then open `http://localhost:9000`.
3. Sign in with username `admin` and password `admin`. Set a new password when prompted.
4. Go to **My Account** then **Security**. Enter a token name and select **Generate**. Copy the token value.
5. Your `SONAR_HOST_URL` is the address your CI runner can reach this server on. `http://localhost:9000` will not work from a GitHub-hosted runner — use a reachable hostname, or run the pipeline on a self-hosted runner.

### Set your SonarQube organization name

1. Open `sonar-project.properties` in this repository (generated by AIRE).
2. Find the line: `sonar.organization=YOUR_ORG_NAME`.
3. Replace `YOUR_ORG_NAME` with your organization key. Find it in SonarQube Cloud under **My Organizations**, or in the URL of your project page.
4. Self-hosted SonarQube does not use organizations — delete the line instead.

### Add the secrets to GitHub

1. Open this repository on GitHub.
2. Go to **Settings** > **Secrets and variables** > **Actions**.
3. Select **New repository secret**.
4. Add `CLAUDE_CODE_OAUTH_TOKEN` with the value from `claude setup-token`.
5. Add `SONAR_TOKEN` with the value from SonarQube.
6. Add `SONAR_HOST_URL` with your server address.

### What the self-repair job does

When any gate fails on a PR, the self-repair job runs `tests/.evals/scripts/auto-fix-agent.sh` using the Claude Code CLI. It reads `eval.json` and the gate logs, fixes only what failed, commits with `fix(ci): self-repair attempt <n>`, and re-runs the failing stage to prove it green. Budget: 3 attempts per CI run (configurable via `retryLimitForSelfRepair` in `tests/.evals/config.json`).

The repair job will never delete a test, suppress a finding, lower a threshold, edit a rubric, or weaken an architecture constraint. Infrastructure failures (expired token, unreachable server, network errors) never trigger source edits — they post a comment naming the cause and stop.

### Gitleaks on organization-owned repos

The pipeline scans for secrets using the gitleaks container image, which needs no token and no licence. If you later switch to the `gitleaks-action` marketplace action, that action requires a `GITLEAKS_LICENSE` secret on organization-owned repositories (free for personal and public repos). See <https://gitleaks.io> for a licence key.

---

## Usage

Start any software development project by stating your intent in the chat, beginning with the phrase **"Using AIRE, ..."** — ideally including the **Epic link** produced by the intent skills (Jira, ADO, or GitHub — whichever tracker you configured), or a plain description for a local-only project or one sourced from Atlas via Helix MCP:

```
Using AIRE, https://yoursite.atlassian.net/browse/PROJ-42        # Jira

Using AIRE, https://dev.azure.com/myorg/MyProject/_workitems/edit/4821   # Azure DevOps

Using AIRE, https://github.com/my-org/my-repo/issues/42          # GitHub

Using AIRE, implement the epic from Helix                        # Atlas via Helix MCP
```

From there:

1. **The AIRE workflow automatically activates** and guides you from there — it detects your workspace, fetches the Epic (if given), and plans the stages.
2. **Answer the structured questions** AIRE asks you. Questions come in multiple-choice format (A, B, C, D…) with an "Other" option — answer inline with the `[Answer]:` tag.
3. **Carefully review every plan the AI generates.** Provide your oversight and validation — this is a team effort; involve the relevant stakeholders at each phase.
4. **Review the execution plan** to see which stages will run (and at what depth). You can override the recommendation and add/remove stages.
5. **Review the artifacts** as they are produced. Planning design stages still ask for your approval; the story set and the whole `dev-implement` / ticket implementation chain are automatic — tell the AI at any point if something needs changing.
6. **Five roots, and AIRE never writes outside them**:
   - `src/` — ALL application code, greenfield and brownfield (a brownfield repo whose code lives
     elsewhere gets that root recorded once in `runtime-artifacts/aire-state.md` `## Code Root`; nothing is mass-moved)
   - `tests/` — `unit/`, `behavior/` ( Gherkin step definitions), `e2e/` (Playwright), `playwright-specs/`, and the eval framework nested at `tests/.evals/` (`config.json`, `rubrics/`, `scripts/`, `behavior/`)
   - `spec/` — specs and docs only: `behavior.feature` at its root (once per cycle) plus four
     subfolders — `plans/` (all planning + design docs as flat files: `architecture.md`, `deep-dive.md`
     + the flat RE docs, `requirements.md`, `stories.md`, `personas.md`, `epic-brief.md`,
     `dependency-graph.yml`, `functional-design.md`, `nfr.md`, `infrastructure-design.md`,
     `application-design.md`), `spec-generation/` (the `*-generation.md` files), `behavior/`
     (`.feature` contracts), `test-plans/` (ve manual test plans), and `context-project/` (human input)
   - `reports/` — generated **outputs** (evidence + review reports + code summaries):
     `unit-test-evidence/`, `behavior-test-evidence/`, `api-contract-test-evidence/`, `eval-evidence/`,
     `reviews/`, `code-security-reviews/`, `ticket-summary/`
   - `runtime-artifacts/` — `audit.md` and `aire-state.md`, plus root-level tool caches

   Plus one generated integration point: `.github/workflows/agentic-eval-pipeline.yml`, built for
   **your** project from its real stack and real thresholds.

Sessions are resumable: state lives in `runtime-artifacts/aire-state.md`, so you can close the chat and pick up exactly where you left off in a fresh session.

---

## Context Project

**What it's for.** A `spec/context-project/existing-knowledge/` folder at the repo root holding human-authored knowledge about your **current project** — how the system works, where things live, what each module does. Files like `interview.md` explain the existing behavior and layout so the AI understands the codebase. This is *context about what already exists*, **not** requirements for the new work.

**How empty `spec/context-project/existing-knowledge/` folder is created.** Brownfield only (it describes existing code, so greenfield projects skip it). Made automatically at the repo root the first time reverse engineering runs, and Workspace Detection ensures it exists on brownfield runs. If it already exists, it's reused as-is — never overwritten. You must manually add the relevant documents (eg: interview.md) to this folder and for more information on how to add them, please refer to the section below.

**How to add docs.** One subfolder per module, named **exactly** after the module in your repo; drop that module's explainer docs inside.

```
context-project/
└── ALIX.BMS/            ← named exactly after the module
    └── interview.md     ← how ALIX.BMS works, where things live
```

**How it's used.** At workflow start AIRE asks: *"Are there any context-project artifacts I should use for this task?"*
- **Yes** → paste the exact file/folder path (e.g. `spec/context-project/existing-knowledge/ALIX.BMS/interview.md`). Only that path is read — used as background context when building `requirements.md` and the plan.
- **No** → the folder is ignored.

The answer is recorded in `runtime-artifacts/aire-state.md`, so a resumed session reuses it without asking again.

---

## New References

**What it's for.** The `spec/context-project/new-references/` subfolder, holding **reference materials for the new work** — UX wireframes, design mockups, UI/UX specifications, API specs, architecture diagrams, research documents, screenshots, or any other reference docs that should guide what the framework builds. This is *forward-looking guidance on what to build*, **not** knowledge about what already exists (that's `spec/context-project/existing-knowledge/`).

**How the empty `spec/context-project/new-references/` folder is created.** Applies to both greenfield and brownfield projects. Created automatically alongside its sibling `existing-knowledge/` inside `spec/context-project/` during Workspace Detection (or `ticket-implement`). If it already exists, it's reused as-is — never overwritten.

**How to add docs.** Organize however makes sense for your project — by feature, by type, or flat. Drop your reference materials inside before starting the workflow.

```
spec/context-project/new-references/
├── wireframes/
│   ├── checkout-flow.png
│   └── dashboard-layout.fig
├── api-spec.yaml
└── architecture-decisions.md
```

**How it's used.** At workflow start AIRE asks: *"Do you have any reference materials I should use for this work?"*
- **Yes** → paste the exact file/folder path(s) (e.g. `spec/context-project/new-references/wireframes/checkout-flow.png`). Those paths are read and used as primary inputs — UX wireframes define the target UI, API specs define the target data contracts, etc.
- **No** → the folder is ignored.

The answer is recorded in `runtime-artifacts/aire-state.md`, so a resumed session reuses it without asking again.

**Where it's consumed.** Requirements Analysis, User Stories, Application Design, Functional Design, Workflow Planning, and Code Generation all read the registered references. UI/wireframe references are also auto-registered as Design References, so the Design Reference Grounding rules (DR-1 through DR-8) enforce that the generated code actually matches the reference.

---

## Resumable Sessions

**AIRE is fully resumable — no session state is ever locked inside a single chat.**

Two files on disk are the single source of truth:

- **`runtime-artifacts/aire-state.md`**
- **`runtime-artifacts/audit.md`** 

Because both files reside in the repository, the AIRE framework retains its state even after a Claude session is closed and reopened, ensuring no loss of context or progress. This makes the workflow durable across interruptions, machine changes, and team handoffs, while maintaining a comprehensive record of all actions.

---

## The End-to-End Journey

A first-time user's complete path, from idea to merged PR:

> ℹ **Have Helix MCP connected?** Steps 1–2 below are optional. If your Epic already exists — sourced
> from Atlas via a connected Helix MCP server, or authored directly in your tracker (Jira, ADO, or
> GitHub) — skip straight to Step 3.

### Step 1 (optional) — Capture the idea: `intent-intake` (skill)

You have a raw idea and no Atlas-backed Epic yet. Invoke the skill `intent-intake` via **`/intent-intake`**. The skill asks whether you have a document (PRD, research notes, Confluence page) or will explain in plain English, gathers exactly **six baseline fields** (outcome, KPI, success signal, out-of-scope, constraints, confidence + unknowns), and — after your confirmation — **pushes an Epic to your configured tracker** (a Jira Epic, an ADO Epic work item, or a GitHub Milestone/tracking issue) labeled `intent-intake`. Fast and deliberately light: no deep elaboration here.

**Output: an Epic on your configured tracker**

### Step 2 (optional) — Deepen it: `intent-refinement` (skill)

Invoke the skill `intent-refinement` via **`/intent-refinement`** and give the Epic reference. The skill fetches the Epic, assesses gaps, runs focused elaboration question batches (measurable success criteria with thresholds, explicit scope/out-of-scope, constraints, domain model, NFRs, risks), and — confirm-first — **updates the Epic on your tracker** to full, verifiable detail with label `intent-refined`.

**Output: the same Epic, now fully detailed.**

### Step 3 — Start development: `Using AIRE, <epic-reference>`

Open Claude Code **in your project workspace** and type, using whichever reference matches your
configured tracker:

```
Using AIRE, https://yoursite.atlassian.net/browse/PROJ-42                    # Jira

Using AIRE, https://dev.azure.com/myorg/MyProject/_workitems/edit/4821       # Azure DevOps

Using AIRE, https://github.com/my-org/my-repo/issues/42                      # GitHub

Using AIRE, implement the epic from Helix                                    # Atlas via Helix MCP
```

The very first thing AIRE asks (once, per project) is **which tracker to use** — Jira, Azure DevOps,
GitHub, or Local only. It never infers this from the link you paste; it always asks explicitly.

When your Epic already lives in Atlas (reachable through a connected Helix MCP server — see
Prerequisite #7), you do not need a tracker link at all. AIRE resolves the Helix MCP provider, pulls
the epic-level intent and existing-system context from Atlas, and proceeds exactly as it would from a
tracker Epic link — you still pick a tracker (or Local) for the stories the workflow generates from it.

The workflow activates: it records the **Parent Epic** in `runtime-artifacts/aire-state.md`, fetches the Epic content into `spec/plans/epic-brief.md` (the brief that defines WHAT to build), and **automatically creates the Epic branch** (`epic/<EPIC-KEY>-<title>`, recorded with the base branch in `runtime-artifacts/aire-state.md`) — all subsequent work happens on this branch and on story branches cut from it. It then runs the **Planning phase** — requirements analysis (including **extension opt-ins**: the Security Baseline is always enforced; resiliency and property-based-testing rules are offered as opt-ins), user stories (generated all at once for a fixed team size of 2 — neither is asked — and pushed to your configured tracker automatically, each story linked to the Parent Epic; nothing is pushed anywhere for Local), the **Dependency Graph**, workflow planning, and (if needed) application design. After requirements approval, the planning artifacts are committed and pushed on the Epic branch (no Epic PR is raised at this point — the Epic PR is raised manually at the end of the cycle via `pr-generator`).

### Step 4 — System-level design, then STOP

The **Implementation phase** runs the conditional system-level design stages (Functional Design, NFR Requirements, NFR Design, Infrastructure Design). At the end of this phase, AIRE automatically:

- Consolidates the approved design into **`spec/plans/architecture.md`** — the system design plus a set of **verifiable constraints** (Section 10) that a diff can be checked against.
- Mechanically derives two rubrics from it into `tests/.evals/rubrics/`: the **architecture rubric** (1:1 from those constraints) and an **OWASP-based security rubric** — these are what the blocking J1/J2 judge gates score every story against in Step 5.
- Generates **this project's own CI pipeline** — `.github/workflows/agentic-eval-pipeline.yml` — built from *your* repo's real stack, real scripts, and the real thresholds in `tests/.evals/config.json`. This is the exact same pipeline that later re-runs every gate on each Pull Request; it is never a generic template.

Then the workflow **commits and pushes the design artifacts (and the new `tests/.evals/`/CI files) on the epic branch** (that push is what unblocks ve) and **hard-stops** at the Development Handoff — code generation never starts automatically. The handoff names both next moves: DEV pulls the epic branch and types `dev-implement` (once per story); ve pulls the same branch and types `/ve-implement <story>` (once per story, in parallel, never waiting for dev code).

### Step 5 — Build story by story: `dev-implement`

Type **`dev-implement`** in the Claude Code chat. It shows the **current ready stories**, you pick one (by ID or tracker key — a Jira key, an ADO work item ID, a GitHub issue number, or the local Story ID), and it runs the full per-story pipeline:

> **Why not parallel in one session?** Stories are built **sequentially** in a session — just type the workflow name and a story number, one story at a time. This is due to **branching**: every story branch is cut from the Epic branch, and prerequisites must be merged into it first. To develop stories **in parallel**, open a **new folder/clone of the same repo**, check the **Dependency Graph**, and run `dev-implement` there on an **independent story** (no shared `requires`).

1. **Doability Checkpoint** — every `requires` prerequisite must be done: its PR confirmed **merged** by a live `gh pr view` check. 🔴 **This checkpoint never merges anything itself — not even an already-approved PR.** Merging is always your own action; if a prerequisite isn't merged yet, the run stops and names exactly what's outstanding (open, draft, conflicted, failing required checks, or just waiting for you to click merge).
2. **Story → In Development** — automatic: the Story Tracker **and** your configured tracker (Jira/ADO/GitHub — or nothing, for Local) are both updated, and the item is assigned to you.
3. **Story Branch Checkpoint** — all prerequisite story PRs must already be **merged into the Epic branch**; then the story branch (`story/N.M-<title>`) is cut **from the Epic branch, never base**.
4. **Baseline capture** — automatic, before any code is written: the *entire* repo test suite runs (`baseline-regression.log`), and the **Static Eval Gate (D1–D7)** — lint, type check, SAST/semgrep, dependency vulnerabilities, licences, cyclomatic complexity, secret scan — runs once to record what's *already* broken, so this story is never blamed for pre-existing debt.
5. **Plan → behaviour spec → code generation** — the implementation plan is announced and executed; a Gherkin `.feature` file (one scenario per acceptance criterion) is written *before* the code, as its contract, then the code is generated. You are not asked to approve any of this.
6. **Unit Test + Coverage** — tests are generated and run, iterating until **≥ 90% coverage** on new code. **Proof artifacts are captured** to `reports/unit-test-evidence/story-N.M/` — the raw runner output (`unit-test-run.log`), the coverage tool's **mandatory machine-readable report** (`coverage-report.*` — lcov/xml/json/HTML), and an `evidence-manifest.md`.
7. **Behavioural (Gherkin) gate, in Podman** — the story's own scenarios (B1), then every *other* feature file in the repo (B2) so nothing else broke, run inside a container for local/CI parity — never natively unless Podman is genuinely unavailable.
8. **API & Contract Testing Gate** — *only when the story adds/changes an API endpoint*: automated tests against the real endpoint(s) covering the happy path, every documented response code, role-based authorization (401 vs. 403), error-response format, request validation, and response schema/contract compliance.
9. **Full regression** — the entire suite runs again and is diffed against the Step 4 baseline. **Any NEW failure was broken by this story, so this story fixes it** in the same run.
10. **Static Eval Gate (D1–D7), re-run** — diffed against the Step 4 baseline; any **new** finding on changed files is fixed in the same run — nothing is ever suppressed to pass it.
11. **AUTO code review** (always runs) — verifies each acceptance criterion, runs a diff-scoped Security Baseline review, and computes the two **blocking judge scores**: **J1** (architecture conformance, scored against the rubric derived in Step 4) and **J2** (OWASP security). **Any Blocker/High finding or a sub-minimum J1/J2 score is fixed automatically** — the framework remediates it, re-runs the regression, and re-reviews, looping (capped at 3 rounds) until the verdict is clean. You are not asked to choose.
12. **Commit + story PR** — once the review is clean this happens on its own: the story commit carries an **`AIRE-Version` trailer**, then `pr-generator` opens the **story PR into the Epic branch** (labeled `aire-v[N]` alongside `ai-generated`) with the full eval scorecard — every gate above, one table — pasted into the PR body, followed by an **AUTO `pr-review`** pass. The PR URL is stored in the Story Tracker and the story **stays `In Development`**.

> **Naming the story is the only input this run takes.** There are no approval gates — steps 5 through 12 run end to end without a prompt. Every self-healing loop above is capped at 3 attempts; on exhaustion the run halts with a Retry-Limit Report instead of pushing through a failing gate.

**Then CI re-verifies the same contract.** The pipeline generated in Step 4 runs on the PR itself — the identical D1–D7, regression, behavioural, and J1/J2 gates, in a clean environment — plus an autonomous self-repair job that uses the Claude Code CLI to fix a failing gate on its own (capped attempts, same non-negotiable rules: never delete a test, suppress a finding, or lower a threshold). CI is an outer ring, not a stricter one — see [CI/CD Eval Pipeline — secrets and setup](#cicd-eval-pipeline--secrets-and-setup).

Merge the story PR into the Epic branch, then type `dev-implement` again for the next story — it lets you pick the next one (its branch cuts from the Epic branch, so a prerequisite's PR must be merged first, which the Doability Checkpoint verifies live). Repeat until all stories are done.

### Step 6 — Verify and ship

- **Build & Test is ve's, not a stage here** — it is not a Implementation stage at epic or story level. ve runs `/ve-implement <story-ID>` per story, in parallel with development (the skill automatically creates a `ve/…` branch from the epic branch + automatic PR raised into the epic branch), then `/ve-list-work` (local **Option B**) on the epic branch (base branch for bug/enhancement cycles) to approve or reject each merged story — **per story, as each PR merges**.
- **`code-review`** (workflow) produces a read-only review report per story or for all stories — a review already auto-runs inside `dev-implement`, so invoke this standalone for re-reviews or an all-stories pass.
- **`remediate`** (workflow) fixes the findings from a chosen review report.
- Invoke the skill `code-security-review` via **`/code-security-review`** to audit the codebase against security baseline rules.
- Invoke the skill `raise-defect` via **`/raise-defect`** to let ve file well-formed bugs into the configured tracker.
- Invoke the skill `pr-generator` via **`/pr-generator`** to raise a PR. It runs **standalone** too: trigger it directly (e.g. "raise a PR") and it asks only which branch to target, then raises the PR from your current branch into it — with the `ai-generated` and `aire-N` labels — for **any** branch → branch (N → M), not just epic/enhancement/bug flows. An ordinary standalone PR takes a lightweight fast path (diff-only summary, no Story Tracker/audit lookups); a standalone epic/bug/enh → base PR keeps the full flow, and an **Epic → Base** PR auto-triggers `archive-epic` (for `[BUG]`/`[ENH]` → Base PRs the archive is **manual** — pr-generator only prints a reminder).
- Invoke the skill `pr-review` via **`/pr-review`** to review an open PR with inline, severity-tagged comments.

### Step 7 — Close the EPIC release cycle: `archive-epic`

When the epic is done (all story PRs merged and ve has approved every story to Ready for testing via `/ve-list-work`, local **Option B**), invoke **`/pr-generator`** on the epic branch: it raises/updates the Epic → Base PR and **auto-triggers `archive-epic`**, which archives the complete `spec/` + `reports/` + `runtime-artifacts/` into `aire-archives/epics/<EPIC-ID>-<epic-name>/`. It generates no reverse-engineering delta and stitches nothing. Merging the Epic PR completes the cycle; the next cycle pulls fresh current-system truth (`spec/plans/deep-dive.md` and the flat RE docs) from Atlas via the Helix MCP.

---

## The Bug-Fix Journey

**Every ticket starts the same way** — type **`ticket-implement <TICKET-ID>`**. The router fetches the ticket and asks **one question** with exactly two inline options: *A) Bug fix* or *B) Enhancement* (it shows a recommendation from the issue type/labels, but your answer decides). Answer **A** and it runs the bug flow below. If state already records this ticket, the router skips the question and resumes where you left off.

```
ticket-implement PROJ-123   →   "What is this ticket about?  A) Bug   B) Enhancement"   →   A
```

### Step 1 — Analyze (bug flow)

An Planning runs on **one branch** — `bug/<TICKET-ID>-<title>`, automatically cut from the base branch (no epic branch, no story branches):

1. **Ticket capture** — the ticket is fetched into `bug-brief.md`; state records `Workflow Type: bug`.
2. **Workspace detection + reverse engineering** — existing RE artifacts are reused; if none exist, RE runs exactly as in the brownfield flow.
3. **Requirements analysis** — generates `requirements.md` from the ticket, scoped to the reported bug.
4. **Impact Analysis + AI-Origin Detection (line-level)** — the affected files and defective lines are identified (`impact-analysis.md`, which later drives the fix plan), and the **Defect Provenance Analyst** agent traces each defective line — not just the file's last change — to the commit that *introduced* it (`git blame` / `git log -L`, following moves and skipping cosmetic commits; omission bugs attribute to the enclosing block). If that introducing change was AI-generated (PR carries the **"ai-generated"** label, the commit has a Claude co-author trailer, or an `AIRE-Version:` trailer), the label **`ai-generated-defect`** is added to the tracker ticket (confirm-first, evidence logged in the audit trail). The bug is also linked to the story/stories that caused the issue on the tracker.
5. **One story** is written from the ticket itself — no team-size question, no tracker push (the ticket already exists), **no Dependency Graph**.
6. Workflow planning + conditional design stages (most are skipped for typical bugs), then the Mandatory stop: the analysis + design artifacts are committed and **pushed** on the bug branch (that push is what unblocks ve), the ve is told to pull that branch and run **`/ve-implement <TICKET-ID>`** in parallel, and the dev is asked **"Continue to bug fix implementation? (yes / no)"**. On **yes** the fix (Step 2) runs in the same session — no second keyword; on **no** the flow halts with state saved and ve carries on regardless.

#### How the bug gets linked to what caused it

As you can see in the fourth point of Step 1, AIRE automatically links the defect to the ticket(s) that introduced it.

The Work link type is **resolved at runtime** from your tracker and matched on the *inward description*. Exactly one type qualifies — **"is caused by"**.

| Your tracker has… | What AIRE does |
|----------------------|-------------------|
| **"is caused by"** | Creates `Bug — is caused by → PROJ-102` under **Linked work items**. |
| **No "is caused by"** | Falls back to a **"relates to"** link **plus** one plain fallback comment on the bug recording the real direction. |

The fallback comment:

```
Is caused by: PROJ-102, PROJ-456

The "is caused by" link type is not available on this Jira instance, so this defect has
been linked to the above work item(s) as "relates to" instead. The direction of causation
is recorded here: this defect is caused by the work item(s) listed above.

Traced from the commit that introduced the defective line(s).
``` 

> **Recommended — add an "is caused by" Work link type to your Jira board (Jira users only).**

### Step 2 — Fix: `bug-fix-implement` (same session, after the mandatory stop)

Runs right after the Step 1 mandatory stop on the dev's **yes**, on the same bug branch (type **`bug-fix-implement`** only to resume a session that answered "no" or ended after analysis on step 1):

1. **Ticket → In Development** (automatic).
2. **Baseline regression run** — the *entire* repo test suite runs **before any change**, recording pre-existing failures so the fix is never blamed for (or hides) what was already broken.
3. **Fix plan → the fix** (the plan is announced, not approved), with unit tests that **validate the fix** ensuring ≥ 90% coverage on changed code.
4. **Full regression** — the entire suite runs again and is compared against the baseline captureed before: **only new failures block and get fixed**; all output is logged in `bug-<TICKET-ID>-summary.md`.
5. **AUTO code review** → any finding is **auto-remediated and re-reviewed until clean** (no approval asked).
6. Once the verdict is clean: **`[BUG]` PR straight to the base branch** (via `pr-generator`), followed by an **AUTO `pr-review`** pass. Meanwhile ve has been running **`/ve-implement <TICKET-ID>`** on the bug branch since the design stages finished — its `ve/…` PR merges into the bug branch, so the test docs reside in this same `[BUG]` PR into base branch.
7. **The ticket stays In Development** — it is never moved forward by this workflow. After the `[BUG]` PR merges into the base branch, ve **invokes `/ve-list-work`** and picks local **Option B** on the base branch, tests the merged fix by executing manual test steps generated by `/ve-implement`, and answers one prompt — `<tracker key> approve` or `<tracker key> reject`. Approve → comment `ve approved the story` + `ve-approved` label, ticket → Ready for Testing; reject → comment `ve rejected the story` + `ve-rejected` label, ticket stays In Development (ve manually log the bug via `/raise-defect`). 
8. **MANUAL archive (bug mode)** — 🔴 **not automatic**. Once the ve's `/ve-implement` test-plan PR have **merged into the bug branch** and all ve work is done and commited to bug branch, pull that branch and invoke **`/archive-epic`** yourself — it archives `spec/` + `reports/` + `runtime-artifacts/` into `aire-archives/bugs/<BUG-ID>-<name>/`. It generates no reverse-engineering delta and stitches nothing. It must run **before** the `[BUG]` PR merges (its commit resides in the open PR).
   🔴 **ve sign-off comes first, on the bug branch**: before the archive, ve runs **`/ve-list-work`** on `bug/<TICKET-ID>-…` — Option C to amend a test plan (commit + push it), Option B to approve and promote the ticket to 🧪 Ready for Testing. Exactly like epic cycles, and for the same reason: the sign-off + test-plan edits get captured in the archive. **`/ve-list-work` never runs on the base branch.**
   Merging the `[BUG]` PR completes the cycle; the next cycle pulls fresh current-system truth from Atlas via the Helix MCP.

---

## The Enhancement Journey

For an existing **Story/Task** in your configured tracker that enhances the current system (not a defect — that's the bug flow).

**It starts exactly like the bug journey** — type **`ticket-implement <TICKET-ID>`**, and answer **B) Enhancement** to the router's one question. That runs the enhancement flow below.

```
ticket-implement PROJ-456   →   "What is this ticket about?  A) Bug   B) Enhancement"   →   B
```

### Single Enhancement flow 

An Planning runs on **one branch** — `enhancement/<TICKET-ID>-<title>`, automatically cut from the base branch (no epic branch, no story branches):

**Phase A — Analysis:**

1. **Ticket capture** — the ticket (Story/Task) is fetched into `enhancement-brief.md`; state records `Workflow Type: enhancement`. A Bug-type ticket triggers a warning to use `bug` fix flow instead.
2. **Workspace detection + enhancement branch** — the branch is created FIRST, before requirements; existing RE artifacts are reused, otherwise RE runs as in the brownfield flow.
3. **Requirements analysis** — generates `requirements.md` from the ticket, scoped to the requested enhancement.
4. **Impact Analysis (NO AI-Origin Detection)** — the affected files/components and blast radius are identified with `file:line` evidence (`impact-analysis.md`, which later drives the implementation plan).
5. **One story** is written from the ticket itself — no team-size question, no tracker push (the ticket already exists), **no Dependency Graph**.
6. Workflow planning + conditional design stages (small enhancements skip most), then the Mandatory stop: the analysis + design artifacts are committed and **pushed** on the enhancement branch (that push is what unblocks ve), the ve is told to pull that branch and run **`/ve-implement <TICKET-ID>`** in parallel, and the dev is asked **"Ready to implement now? (yes / no)"** — on **no** it halts with state saved (re-invoking resumes at this checkpoint) and ve carries on regardless; on **yes** it continues with the implementation plan and code generation in the SAME flow.

**Phase B — Implementation (after "yes"):**

1. **Ticket → In Development** (automatic) — the ticket is also assigned to you.
2. **Baseline regression run** — the *entire* repo test suite runs **before any change**, recording pre-existing failures.
3. **Implementation plan → your approval → the code**, with unit tests and ≥ 90% coverage on new/changed code.
4. **Full regression** — the entire suite runs again vs the baseline: **only new failures block and get fixed**; all output is logged in `enhancement-<TICKET-ID>-summary.md`.
5. **AUTO code review** → any finding is **auto-remediated and re-reviewed until clean** (same automatic behaviour as `dev-implement`).
6. Once the verdict is clean: **`[ENH]` PR straight to the base branch** (via `pr-generator`), followed by an **AUTO `pr-review`** pass. Meanwhile ve has been running **`/ve-implement <TICKET-ID>`** on the enhancement branch since the design stages finished — its `ve/…` PR merges into the enhancement branch, so the test docs reside in this same `[ENH]` PR into base.
7. **The ticket stays In Development** — after the `[ENH]` PR merges, ve **invokes `/ve-list-work`** and picks local **Option B** on the base branch, tests the merged changes by executing manual test steps generated by `/ve-implement`, and answers one prompt — `<tracker key> approve` or `<tracker key> reject`. Approve → comment `ve approved the story` + `ve-approved` label and Ticket → Ready for Testing; reject → comment `ve rejected the story` + `ve-rejected` label, ticket stays In Development (ve manually log the bug via `/raise-defect`).
8. **MANUAL archive (enhancement mode)** — 🔴 **not automatic**. Once the ve's `/ve-implement` test-plan PR have **merged into the enhancement branch** and  all ve work is done and commited into the enhancement branch, pull that branch and invoke **`/archive-epic`** yourself — it archives `spec/` + `reports/` + `runtime-artifacts/` into `aire-archives/enhancements/<ENH-ID>-<name>/`. It generates no reverse-engineering delta and stitches nothing. It must run **before** the `[ENH]` PR merges (its commit resides in the open PR).
   🔴 **ve sign-off comes first, on the enhancement branch**: before the archive, ve runs **`/ve-list-work`** on `enhancement/<TICKET-ID>-…` — Option C to amend a test plan (commit + push it), Option B to approve and promote the ticket to 🧪 Ready for Testing. Exactly like epic cycles, and for the same reason: the Story Tracker still exists there, and the sign-off + test-plan edits get captured in the archive. **`/ve-list-work` never runs on the base branch.**
   Merging the `[ENH]` PR completes the cycle; the next cycle pulls fresh current-system truth from Atlas via the Helix MCP.

---

## Verification Engineer Operating Guide

This section is written for the Verification Engineer (VE). It states what you are responsible for, where you do the work, and the exact order in which to do it.

### Skills you use

| Skill | Purpose | When you run it |
|-------|---------|------------------|
| **`/ve-implement`** | Author the manual Test Plan for one story/ticket — as manual test steps derived from its acceptance criteria. Never reads application code. | As soon as the design stages finish, in parallel with development. |
| **`/ve-list-work`** | List merged/testable work (Option A), record your Approve/Reject sign-off (Option B), or amend a test plan (Option C). | Once the dev's PR for that story/ticket has merged. |
| **`/raise-defect`** | Log a bug you found while testing as a well-formed tracker ticket. | Whenever you reject a story, or find an issue during testing. |
| **`/playwright-implement`** | Turn an already-**Approved** manual UI test plan into real, executable Playwright automation — using Playwright's own Planner/Generator/Healer agents. | Once **both** the dev's PR and your own `/ve-implement` test-plan PR have merged for same story — see Step 3 below. |

### Your responsibility

Test Plan belongs to you. Your work runs **in parallel with development**, not after it. You begin as soon as the design stages of Implementation phase finish, which is well before any application code exists. Nothing you do at that point depends on the developer.


### Where you work

Both skills operate on the cycle's **integration branch**. Which branch that is depends on the type of work, and each skill resolves it for you from the project state file and announces it:

| Cycle type | Integration branch | Where the development pull requests merge |
|------------|--------------------|-------------------------------------------|
| Epic (greenfield or brownfield) | The epic branch, for example `epic/PROJ-50-checkout` | Each story's `[STORY]` pull request merges into the epic branch |
| Bug | The base branch, for example `Staging` | The single `[BUG]` pull request merges into the base branch |
| Enhancement | The base branch | The single `[ENH]` pull request merges into the base branch |

All of your generated documentation lives under `spec/test-plans/<STORY-ID>-<title>/`, one folder per story.

### Step 1 — Author the test plan: `/ve-implement`

**When to start.** The moment the workflow reaches its design handoff. At that point the framework commits and pushes the requirements and design artifacts to the integration branch specifically so that you can start; the message shown at that handoff names the branch and tells you to run this skill. On an epic you run the skill once per story; on a bug or enhancement you run it once for the ticket.

**What to do.**

1. Get on the integration branch and take the latest:

   ```
   git fetch origin
   git checkout <integration-branch>
   git pull --ff-only
   ```

2. Type the skill, naming the story or ticket:

   ```
   /ve-implement PROJ-102
   ```

   A story number also works on an epic cycle, for example `/ve-implement 1.2`. Invoking it with no argument makes the skill ask which story you mean

**What the skill does.** It cuts its own branch, `ve/<TICKET-ID>-<title>`, from the integration branch. It reads the story's acceptance criteria from the configured tracker, together with the requirements and the implementation design artifacts, and decides which test plans apply — integration, end-to-end, API, contract, security, performance, and accessibility. It writes each applicable plan as numbered **manual test steps** into `spec/test-plans/<STORY-ID>-<title>/`, with an index file summarising the plans and the coverage. Every test case names the acceptance criterion it covers, and every acceptance criterion must be covered; that coverage check is a blocking gate.

**What you are asked.** Before any file is written, the skill confirms which test plans it considers applicable. When the plans are complete, it presents a summary and asks you to approve them or request changes. If you request changes, it revises and asks again. Once approved, it asks permission before pushing the branch and opening its pull request.

**What you get.** A pull request titled `[TEST][<TICKET-ID>] Test Plan — <story title>`, raised from `ve/<TICKET-ID>-<title>` back into the integration branch, labelled `ai-generated` and `aire-v<version>`. On a bug or enhancement cycle this means your test documentation travels into the base branch on the same `[BUG]` or `[ENH]` pull request as the fix. Parallel runs by different VE and Developer do not conflict, because these files are configured to merge by appending, .gitattributes.

**What this skill deliberately does not do.** It writes no automated test scripts, executes no tests, changes no application code, and never changes a story's status in the tracker.

**After the run.** Merge your test-documentation pull request into the integration branch. Do not execute the steps yet — see Step 2.

### Step 2 — Execute the steps, then sign off: `/ve-list-work`

**When to start.** Only after the developer's pull request for that story has **merged** into the integration branch. Until then there is nothing to test. On an epic you do this per story as each story's pull request merges; you do not wait for the whole epic.

**What to do.**

1. Get on the integration branch and take the latest, as in Step 1. The skill resolves the correct branch itself, tells you which one it expects, and asks before switching.

2. Type the skill:

   ```
   /ve-list-work
   ```

3. Choose one of three local actions when prompted:

   | Option | Purpose | What it changes |
   |--------|---------|-----------------|
   | A | List the stories whose development pull request has merged and which are still In Development. Status is read live from the configured tracker rather than trusted from the local state file. | Nothing |
   | B | Record your sign-off decision after you have tested the merged work. | The Story Tracker, the configured tracker, and the audit log |
   | C | Request a change to a test plan that `/ve-implement` already generated — add or adjust a manual test case, traced to an acceptance criterion. | The test plan files only |

4. **Build the system and execute the test steps.** Option A gives you the list of stories that are merged and testable, and names each one's test-plan folder. Build and run the system locally from the integration branch, then execute the manual test steps in `spec/test-plans/<TICKET-ID>-<title>/`.

5. **Record the decision with Option B.** The skill shows the merged, testable items and asks a single question. You answer with one decision per item, for example `1.1 approve, PROJ-103 reject`.

   - **Approve** adds the tracker comment `VE approved the story`, applies the `ve-approved` label, and transitions the item from In Development to **Ready for Testing** in both the Story Tracker and the configured tracker.
   - **Reject** adds the tracker comment `VE rejected the story`, applies the `ve-rejected` label, and deliberately leaves the item **In Development** for the developer to address. The skill then tells you to log the finding as a tracked defect manually by a raise-defect skill.

   On an epic cycle, once every story has been approved the skill offers, with your confirmation, to move the parent epic to Ready for Testing.

**A note on Option C.** Option C edits the test-plan files in your working tree. It does not commit, push, or open a pull request for you. Commit and push that change yourself so it reaches the branch;

### Step 3 — Automate the UI: `/playwright-implement`

Once a story's manual UI test steps exist and both of that story's PRs have landed, you can turn the
UI-relevant cases into real, executable Playwright scripts — driven by Playwright's **own** official
Test Agents (Planner, Generator, Healer), never a re-implementation of them. Backend/API cases stay
manual-only; this extension is UI/browser automation only, and it never touches application code, the
Story Tracker, or any tracker status.

**The sequence, in order:**

```
1. The DEV's story PR merges into the epic branch (bug/enhancement branch, for those cycles)
2. YOUR OWN /ve-implement test-plan PR ("[TEST]...") merges into that same branch
3. You invoke:  /playwright-implement <story or TICKET-ID>
        │
        ▼
   Prerequisite Gate runs automatically:
     • Playwright + its official agents are installed and scaffolded
     • the local frontend server is up
     • fixture data / test accounts are seeded
     • the shared seed test (tests/e2e/seed.spec.ts) covers this story's starting state
        │
        ├─ a check fails ──▶ STOPS and tells you exactly what's missing
        │
        └─ all checks pass ──▶ automation proceeds:
              Planner drafts a plan ──▶  you approve it ──▶ Generator writes the specs
              ──▶ local headed run ──▶ Healer fixes failures ──▶  push gate
              ──▶ pushed directly to the integration branch (no PR — the push gate IS the review)
```

**What you get.** `tests/e2e/<story-slug>/` (the generated Playwright specs),
`tests/playwright-specs/<story-slug>.md` (the Approved plan), and
`spec/test-plans/<TICKET-ID>-<title>/automation-summary.md` (AC
coverage — automated UI cases plus the remaining manual ones, combined). A failure the Healer can't
fix is marked `test.fixme()` and flagged as a candidate product defect — raise it with `/raise-defect`.

**Run it in its own terminal.** It's a longer, sequential flow meant to run alongside `/ve-list-work`
working the Approve/Reject queue for other stories in a separate terminal — not inside it.

### The order of work for one story

1. The workflow reaches its design handoff and pushes the requirements and design artifacts to the integration branch.
2. You pull that branch and run `/ve-implement <TICKET-ID>`. You review and approve the generated plans, then allow the push and the pull request.
3. You merge your test-documentation pull request into the integration branch.
4. You repeat steps 2 and 3 for the next story while the developer continues to build. Development and Test Plan proceed independently.
5. The developer's pull request for the story merges into the integration branch.
6. You run `/ve-list-work` on integration branch and pick Option A to confirm what has merged.
7. You build the system locally from the integration branch and execute the manual test steps generated by `/ve-implement`.
8. You run `/ve-list-work` again and pick Option B to approve or reject a story. Approved stories move to Ready for Testing; rejected items stay In Development and you manually log a defect by `/raise-defect` skill.
9. Optionally, once both PRs for that story are merged, invoke `/playwright-implement <story>` to turn its UI-relevant manual cases into executable Playwright automation (Step 3 above).


---

## Dependency Graph

The Dependency Graph stage is what keeps story development **correctly ordered** in AIRE.

**The idea**: every story gets a `requires` list — the stories that must be fully done before it can start. From those dependencies, the graph shows at any moment which stories are **ready** (no unfinished prerequisites) and which are blocked by what.

At each `dev-implement` invocation, the workflow reads the graph and shows the currently ready stories; you pick the next one to build. Two checkpoints enforce the graph: the **Doability Checkpoint** blocks any story whose `requires` prerequisites aren't done — each one must already be `Ready for testing`, or have its PR confirmed merged by a live check — and the **Story Branch Checkpoint** additionally requires all prerequisite story PRs to be merged into the Epic branch before the new story branch is cut. Stories are developed **one at a time per epic** — each story branch cuts from the Epic branch after the previous story's PR has merged.

---

## Keyword Workflows

These are typed directly in chat (any session — they self-load their rules and can resume from state):

### `dev-implement` — build one story

Turns one user story into working code. It shows you which stories are ready to build and you pick one — **that is the only thing it asks you**. From there it plans, writes the code, tests it to ≥90% coverage, runs the regressions, reviews itself, **fixes anything the review finds (looping until the review is clean)**, then commits and raises the PR — updating the story's status locally and in the configured tracker as it goes.

> Sequential per session (because of branching): one story at a time. For parallel work, use a new folder/clone of the same repo and pick an independent story from the Dependency Graph.

### `code-review` — review the code

Reviews the code of one story (or all stories) against what the story promised and general quality standards. It only reads and reports — it never changes code.

### `remediate` — fix what the review found

Takes a review report and fixes the issues in it, then marks them resolved in the report. This also runs **automatically** inside every implement workflow whenever the auto code review reports findings, re-reviewing until the verdict is clean. Invoked standalone it stays confirm-first, and you should re-run `code-review` afterwards if serious issues were fixed.

### `ticket-implement <TICKET-ID>` — one front door for bug OR enhancement

This router fetches the ticket, asks **one question** — *"What is this ticket about? A) Bug fix B) Enhancement"* (with a recommendation from the issue type/labels; your answer decides) — then runs the required workflow.

---

## Claude Code Skills

Located in `.claude/skills/` — invoked by natural language or `/skill-name`.

| Skill | What it does |
|-------|--------------|
| **`intent-intake`** | The light front-door: turns a raw idea in natural language (or a PRD/doc/link) into a six-field baseline intent and **pushes it to your configured tracker as an Epic** (Jira, ADO, GitHub, or local-only).  |
| **`intent-refinement`** | Fetches an existing Epic from your configured tracker, runs structured elaboration batches until the intent is **verifiable** (measurable criteria + thresholds, scope, constraints, domain model, risks), and updates the Epic on the tracker with the refined detail. |
| **`story-audit`** | Audits an existing Story or Epic — in whichever tracker is configured (Jira, Azure DevOps, GitHub) or directly from stories.md for Local — against the AIRE quality bar. Fetches the issue, assesses what's present vs missing, scores it, and offers to fill gaps through targeted questions — then updates the issue in the tracker with the improvements (or the local story file, for Local). Works for any issue type (Story, Epic, Task) but applies the appropriate checklist for each. |
| **`ve-implement`** | ve Test Plan (black-box), **per story, in parallel with development** — the dev's code does not need to exist, be built, or be merged, so ve can start the moment the design stages finish. Run it as `/ve-implement <story-ID>` on the **epic branch** (epic cycles) or the **bug/enhancement branch** (ticket cycles), **as soon as the design stages of implementation phase finish**: it cuts an **`ve/<ID>-<title>`** branch from that latest branch, reads the story's acceptance criteria from the configured tracker, requirements and design artifacts — **never application source code** — decides which test plans apply (integration, E2E, API, contract, security, performance, accessibility) and writes them as **manual test steps** into `spec/test-plans/<STORY-ID>-<title>/`, one folder per story, every test case traced to an acceptance criterion and every criterion covered. It then **commits and raises a PR back to that same branch** — labeled `ai-generated` + `aire-v[N]` — logged in `runtime-artifacts/audit.md`; `.gitattributes` merges these files by append so parallel ve runs never conflict. One story per run. |
| **`code-security-review`** | Full-codebase audit against the 16 Security Baseline rules (SECURITY-01…16: encryption, headers, input validation, SSRF, uploads, access control, CSRF, JWT, credentials, sessions, supply chain, XXE, alerting, error handling, crypto standards). Findings by severity, dated report in `reports/code-security-reviews/`. |
| **`raise-defect`** | Interviews the ve through a fixed field set — Title, Description, Severity, Environment Found, Discovery Activity (Components always `Default`, Associated Org always `All`) — then, after the ve approves the drafted ticket, creates the bug in your configured tracker (Jira, ADO, GitHub, or local) labeled `bug`, `defect`, `ai-generated`, `aire`, `aire-v[N]`. The developer picks it up via `ticket-implement <TICKET-ID>`. |
| **`pr-generator`** | Raises a GitHub PR from the current branch into a target branch, tagged with `ai-generated` and `aire-N` labels and an `AIRE Framework: vN` line in the body. In automatic workflow mode it grounds the summary in the **Story Tracker** and **audit trail** (never just the raw diff) and titles the PR with an **`[EPIC]`, `[STORY]`, `[BUG]` or `[ENH]`** prefix. **Can also be invoked standalone** (e.g. "/pr-generator") to open a PR from **any branch into any target branch** (N → M): it asks only which branch to target, then raises it with both labels.|
| **`ve-list-work`** | Once on the integration branch (epic branch for epic cycles, base branch for bug/enhancement cycles), it asks a **local A/B/C menu**: **A) List** — reports what dev has merged (test these, using the `/ve-implement` steps) vs what is still in development, status read **live from the tracker**, writes nothing. **B) Approve/Reject** — the sign-off itself: pulls the latest, confirms each recorded PR's real merge state with `gh`, reports the same merged/in-development table, then ve answers **one prompt with one decision per item** — `<story or tracker key> approve` / `<story or tracker key> reject`. Approved → tracker comment `ve approved the story` + **`ve-approved`** label + moved to Ready for Testing in the Story Tracker **and** the tracker; rejected → comment `ve rejected the story` + **`ve-rejected`** label and it **stays In Development** for dev to fix (ve log the bug manually via `/raise-defect`). **Runnable per story as each PR merges** — only the optional Parent Epic move waits until every story is approved. **C) Request changes to a test plan** — adds/adjusts a manual test case in a story's `/ve-implement`-generated test plan, traced to an acceptance criterion, without touching code, branches, or status. Every run closes with a confirm-first Approve/Request-Changes checkpoint.|
| **`pr-review`** | Senior-reviewer pass over a PR: reads diff + description, cross-checks stories and audit context, drafts inline comments tagged 🔴 Blocker / 🟠 Issue / 🟡 Nit /  Question / 🟢 Praise plus a verdict and a "Suggested for human review" section.|
| **`playwright-implement`** | Orchestrates Playwright's **own** official Test Agents (Planner, Generator, Healer — installed once via `npx playwright init-agents --loop=claude`) to turn a story's already-Approved manual UI test steps into executable Playwright automation. Runs only after both the dev's story PR and ve's own `/ve-implement` test-plan PR have merged into the integration branch; gated by a Prerequisite Gate (Playwright + agents installed, local server up, fixtures seeded), a Seed Test Gate, a mandatory approval on the Planner's plan, and a push gate before pushing directly to the integration branch (no PR). UI/browser automation only — backend/API cases stay manual. |
| **`reverse-engineering-root`** | Generates the **root** reverse engineering artifacts once at the workspace root — a single artifact set covering **all monorepo modules**, which every module then reuses for development. Run upfront before an epic cycle (or let each cycle refresh current-system truth fresh from Atlas via the Helix MCP) |
| **`archive-epic`** | Closes an **epic, bug, or enhancement** release cycle: archives the complete `spec/` + `reports/` + `runtime-artifacts/` (runtime-artifacts/audit.md, runtime-artifacts/aire-state.md, RE docs, etc..) into `aire-archives/epics/<EPIC-ID>-<name>/`, `aire-archives/bugs/<BUG-ID>-<name>/`, or `aire-archives/enhancements/<ENH-ID>-<name>/` per the `Workflow Type` in state. It generates **no** reverse-engineering delta and stitches nothing — current-system truth (`spec/plans/deep-dive.md` and the flat RE docs) is refreshed fresh from Atlas via the Helix MCP at the start of each new cycle. **Auto-triggered only for epic cycles** (pr-generator, Epic → Base PR); **bug and enhancement cycles are archived manually** by the operator once the ve's work is completed and all the artifacts are merged into the cycle branch. |

---

## Framework Distribution — auto-install & auto-update AIRE in any repo

AIRE ships itself to consuming teams via an automated GitHub workflow
([`.github/workflows/distribute-framework.yml`](.github/workflows/distribute-framework.yml)).
Any repo registered in the subscriber registry
([`.github/aire-subscribers.yml`](.github/aire-subscribers.yml)) automatically receives
the framework **as a Pull Request** — both the first-time installation and every subsequent
framework update.

### How it works

1. **A team onboards once** — they hand over a PAT for their repo and the repo URL.
2. **Merging their registry entry to `main` raises the first-time installation PR** in their repo,
   carrying the complete framework: `CLAUDE.md`, `aire-workflow/` (incl. `aire-workflow-diagram.md`),
   the `.claude/skills/`, `.gitattributes` and a `.aire-version` stamp. Onboarding targets **only the newly
   added repo(s)** — existing subscribers are not touched by registry changes.
3. **From then on, every PR merged into `main` of this repo** that touches framework files
   (`CLAUDE.md`, `aire-workflow/`, `.claude/skills/`, `.gitattributes`)
   automatically raises an update PR in **every** subscriber repo. Non-framework changes
   (e.g. `README.md`) never distribute. Repos already on the latest version are skipped.
   **PR tracking**: each subscriber has at most **one open AIRE PR** (stable branch
   `aire/framework-update`) — if the previous PR is still unmerged when a new version ships,
   that same PR is updated in place (commits, title, description) instead of opening a second
   one; a brand-new PR is created only after the previous one was merged or closed.

### Onboarding a new team/repo

| Step | Who | Action |
|------|-----|--------|
| 1 | Consuming team | Create a GitHub PAT for their repo — fine-grained with **Contents: Read & write** + **Pull requests: Read & write** (or classic PAT with `repo` scope) — and share it with an AIRE maintainer |
| 2 | AIRE maintainer | Store the PAT as an Actions secret in **this** repo (*Settings → Secrets and variables → Actions*), named e.g. `AIRE_PAT_<TEAM>` |
| 3 | AIRE maintainer | Add the entry to [`.github/aire-subscribers.yml`](.github/aire-subscribers.yml) and merge to `main`: |

```yaml
repos:
  - repo: some-org/their-repo              # owner/name or full GitHub URL
    token_secret: AIRE_PAT_THEIR_TEAM    # NAME of the Actions secret holding the PAT
    # target_branch: develop               # optional — defaults to the repo's default branch
```

The installation PR appears in the subscriber repo within minutes. A single subscriber failing
(e.g. revoked PAT) never blocks distribution to the others, and each run's summary lists the PR
raised (or the up-to-date skip) per repo.

> **Security**: the registry stores only the **name** of the Actions secret — **never** paste
> a raw PAT into the YAML file. Tokens live encrypted in this repo's Actions secrets.

### Version control

The distributed version is read live from the canonical `AIRE Framework Version` line in
`CLAUDE.md`. Update PRs are titled `[AIRE] Framework update → v[N]`, labeled `aire-v[N]`,
carry an `AIRE-Version: [N]` commit trailer, and write the installed version + source commit
into the subscriber's `.aire-version` file — so you can always tell which framework version any
repo is running.

#### Updating the version — files to update manually

When updating the framework, please ensure the version is also updated in these files:

| File | 
|------|
| **`CLAUDE.md`** | 
| **`.claude/skills/pr-generator/SKILL.md`** | 

---

## Agents


| Agent | Invoked by | What it covers |
|-------|-----------|----------------|
| **`code-security-review-agent`** | `/code-security-review` skill | A senior application-security engineer persona. Maps the codebase's attack surface (entry points, data stores, auth boundaries), audits every file against all 16 Security Baseline rules (SECURITY-01…16), classifies findings on a four-level severity scale, and produces a dated report with evidence, remediation, and an OWASP-mapped compliance matrix. | 
| **`ve-implement-agent`** | `/ve-implement` skill | A senior ve persona that owns **Test Plan**, per story, in parallel with development. Reads the story's acceptance criteria, requirements, epic brief, design and reverse-engineering artifacts — **never application source code**, because the code may not exist yet. Executes `implementation/test-plan.md`: decides which test plans apply, then writes them as **manual test steps** (`TC-…` cases with preconditions, steps, expected result, pass/fail criteria, cleanup) into `spec/test-plans/<Story-ID>-<title>/`, gated on every acceptance criterion being covered.|
| **`archive-epic-agent`** | `/archive-epic` skill (auto-triggered by `pr-generator` on **Epic→Base PRs only**; **bug and enhancement cycles are invoked manually** by the operator after the ve test-plan PR merges into the cycle branch) | A release-manager persona that closes an epic, bug, or enhancement cycle: archives the complete `spec/` + `reports/` + `runtime-artifacts/` into `aire-archives/epics\|bugs\|enhancements/` and commits so the archive resides the open PR. It generates no reverse-engineering delta and stitches nothing — current-system truth is refreshed fresh from Atlas via the Helix MCP at the start of each new cycle. |
| **`defect-provenance-analyst`** | `bug-fix` workflow | A read-only code archaeologist for **line-level AI-origin detection**: traces each defective line past cosmetic commits to the commit that *introduced* the logic (`git blame -w -M -C` / `git log -L`), resolves its PR, and issues an AI-generated / human verdict on **positive evidence only** (AI-Generated PR label, Claude co-author trailer, or `AIRE-Version` trailer). Also resolves the **originating tracker ticket** that shipped the line — story, bug fix or enhancement, read from the PR title or commit subject or branch name — which the bug flow links automatically. |
| **`playwright-implement-agent`** | `/playwright-implement` skill | An orchestrator persona that never re-implements Playwright's own agents — it invokes the real, installed `playwright-test-{planner,generator,healer}` subagents by name, gates the human checkpoints (Seed Test Gate, Planner-plan approval, push gate) this framework requires around them, and runs the Generator/Healer strictly one scenario at a time to avoid the confirmed zombie-process failure mode of parallel invocations. |
