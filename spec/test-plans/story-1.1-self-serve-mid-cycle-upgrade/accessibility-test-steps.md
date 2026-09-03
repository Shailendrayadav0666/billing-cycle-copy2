# Accessibility Test Steps — Story 1.1 Self-Serve Mid-Cycle Upgrade: Standard → Premium

## System Under Test
| Item | Value |
|------|-------|
| Branch | `epic/3157-mid-cycle-subscription-upgrade` |
| This story's merged PR | https://github.com/Shailendrayadav0666/billing-cycle-copy2/pull/7 (merged 2026-09-03T13:45:28Z, commit `b96fbe3`) |
| Confirm the story is in the build | `git log --oneline \| grep -i "self-serve mid-cycle"` |
| How to build & run it | Follow the project's own build docs (`src/frontend/README.md`). This plan does not restate them. |
| Local base URL / port | Frontend: `http://localhost:5173` (backend must also be running at `http://127.0.0.1:8000`) |
| Local services that must be up | Backend (uvicorn) and frontend (vite dev) dev servers |
| Test data / accounts to seed | Seed user `tpg@example.com` / `password` |

> If the build or local run fails, that is a **blocker on the dev team** — report it and do not log functional failures against a system that never started.

---

### TC-A11Y-01 — Keyboard-only operation of the upgrade flow

| Field | Value |
|-------|-------|
| **Traces to** | AC-1, AC-2, AC-3 (new interactive elements) |
| **Type** | Accessibility |
| **Priority** | P2 |
| **WCAG** | 2.1.1 Keyboard |
| **Preconditions** | Logged in as a Standard subscriber; mouse disconnected or unused |
| **Test data** | `tpg@example.com` |

**Steps**
1. Using only Tab/Shift+Tab/Enter/Space/Escape, navigate to the Billing page and reach the **Upgrade to Premium** button.
2. Press Enter/Space to activate it.
3. Once the modal opens, Tab through its contents to reach **Confirm Upgrade** and **Cancel**.
4. Activate **Cancel** via keyboard; re-open the modal and activate **Confirm Upgrade** via keyboard.

**Expected result**
- Every action in steps 1-4 is achievable with keyboard alone; focus never gets trapped outside the modal while it is open, and closing the modal returns focus to a sensible location (e.g. back to the Upgrade button).

**Pass/Fail criteria**: FAIL if any control is unreachable or unactivatable by keyboard, or if focus is lost/trapped incorrectly.
**Cleanup**: Restart the backend process if an upgrade was actually completed.

---

### TC-A11Y-02 — Modal is announced correctly to assistive technology

| Field | Value |
|-------|-------|
| **Traces to** | AC-2 |
| **Type** | Accessibility |
| **Priority** | P2 |
| **WCAG** | 4.1.2 Name, Role, Value |
| **Preconditions** | Screen reader active (NVDA/VoiceOver/JAWS — whichever is available) |
| **Test data** | `tpg@example.com` |

**Steps**
1. With a screen reader running, open the upgrade modal.
2. Listen for how the modal is announced.

**Expected result**
- The modal is announced as a dialog (e.g. via `role="dialog"`/`aria-modal`), and its heading/purpose ("Upgrade to Premium") is read out. The prorated charge amount and both action buttons are announced with clear, unambiguous labels (not just "button").

**Pass/Fail criteria**: FAIL if the modal is not announced as a dialog, or if any control has no accessible name.
**Cleanup**: None.

---

### TC-A11Y-03 — Error and success states are announced, not just visual

| Field | Value |
|-------|-------|
| **Traces to** | AC-4 (both outcomes) |
| **Type** | Accessibility |
| **Priority** | P2 |
| **WCAG** | 4.1.3 Status Messages |
| **Preconditions** | Screen reader active |
| **Test data** | `tpg@example.com` (success), a `fail`-prefixed account (decline) |

**Steps**
1. With a screen reader running, trigger the decline path (TC-E2E-03) and listen for whether the inline error is announced automatically (not just visible).
2. Separately, trigger the success path (TC-E2E-01) and listen for whether the success banner is announced automatically.

**Expected result**
- Both the error message and the success banner are announced without the user having to manually navigate to find them (e.g. via an ARIA live region).

**Pass/Fail criteria**: FAIL if either message is purely visual with no corresponding announcement.
**Cleanup**: Restart the backend process.

---

### TC-A11Y-04 — Zoom to 200% does not break the upgrade flow

| Field | Value |
|-------|-------|
| **Traces to** | AC-1, AC-2, AC-3 |
| **Type** | Accessibility |
| **Priority** | P3 |
| **WCAG** | 1.4.4 Resize Text |
| **Preconditions** | Browser zoom set to 200% |
| **Test data** | `tpg@example.com` |

**Steps**
1. Set browser zoom to 200%.
2. Repeat TC-E2E-01 (happy path) at this zoom level.

**Expected result**
- All CTA, modal content, and buttons remain visible, readable, and operable at 200% zoom — no clipped text, no overlapping/unreachable controls.

**Pass/Fail criteria**: FAIL if any part of the flow becomes unusable at 200% zoom.
**Cleanup**: Reset zoom to 100%; restart the backend process.

---

## Coverage
- AC-1, AC-2, AC-3 → TC-A11Y-01, TC-A11Y-04
- AC-2 → TC-A11Y-02
- AC-4 → TC-A11Y-03
