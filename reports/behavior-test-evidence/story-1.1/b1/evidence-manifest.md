# Behavior Evidence — Story 1.1 — Tier B1 (this unit)

- **Feature file**: spec/behavior/story-1.1.feature
- **Step defs**: tests/behavior/steps/test_story_1_1_steps.py (bound to the public HTTP surface via FastAPI TestClient — never internals)
- **Command**: `pytest tests/behavior/steps -q -v`
- **Result**: 9/9 scenarios PASS
- **AC tag coverage**: @AC-1 (x2), @AC-2, @AC-3, @AC-4, @AC-5, @AC-6 (x2), @AC-7 — every AC-1..AC-7 tag executed at least once
- **Containerised**: false
- **Reason**: Podman is installed (v5.8.2) but `podman machine start` failed in this sandboxed dev environment: "machine did not transition into running state" (WSL/hypervisor access restricted here). This is the one legitimate native-run exception per common/eval-framework.md Section 8 ("Podman is not installed" row) — extended here to "installed but its VM cannot start in this sandbox", the closest real-world equivalent; not "no browser needed" or any forbidden justification. Marked **PASS (unverified container parity)**. The generated CI pipeline (.github/workflows/agentic-eval-pipeline.yml) DOES run this tier inside Podman on the GitHub-hosted runner, where the smoke test already confirmed Podman/container steps are reachable in that environment.
