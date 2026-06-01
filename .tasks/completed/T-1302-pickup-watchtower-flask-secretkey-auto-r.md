---
id: T-1302
name: "Pickup: Watchtower Flask secret_key auto-regenerates on every restart — breaks CSRF for existing browser sessions (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1125. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T18:43:05Z
last_update: 2026-04-18T22:45:58Z
date_finished: 2026-04-18T22:45:32Z
---

# T-1302: Pickup: Watchtower Flask secret_key auto-regenerates on every restart — breaks CSRF for existing browser sessions (from termlink)

## Problem Statement

`web/app.py` (lines 47-55) auto-generates a new Flask `secret_key` on every process start when `FW_SECRET_KEY` is unset. Because `session["_csrf_token"]` is cookie-signed with that key, every restart invalidates all existing browser sessions. Users hit `403 Forbidden — CSRF token missing or invalid` on any POST form until they hard-refresh every open tab.

Source: pickup P-029 from termlink (T-1125). Fix already implemented upstream at `termlink@0373828e` and verified to hold across restarts. Upstream ask: absorb pattern so consumers don't patch vendored copies.

## Assumptions

1. Persisting the generated key to `PROJECT_ROOT/.context/working/.fw-secret-key` (chmod 600) is acceptable for dev and production environments alike.
2. The env var (`FW_SECRET_KEY`) must continue to win when set — operators retain full override.
3. `.context/working/` already exists and is git-ignored.

## Exploration Plan

No spikes required — the fix has already been implemented, deployed, and verified in termlink. Exploration reduces to:
- Confirm the three assumptions against the framework's current file layout.
- Confirm fix scope is one function + one import block (≤25 lines).
- Design acceptance tests that prove the key is stable across two `create_app()` invocations.

## Technical Constraints

- File must be written with mode `0o600` (key material — anyone with read access can forge CSRF tokens).
- Must log the source label (`env` / `file` / `generated`), never the key itself.
- Must work even if `.context/working/` doesn't exist yet (`mkdir -p` pattern).
- Must not introduce a new Python dependency.

## Scope Fence

**IN:** Replace the 4-line key resolution in `web/app.py` with a `_resolve_secret_key()` helper that does env → file → generate-and-persist. Add unit test proving stability across two `create_app()` calls.

**OUT:** Rotation policy, encryption at rest, multi-instance key sharing (Watchtower is single-process). These are separate concerns.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (T-1306 implementation + tests confirm all three assumptions)
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
grep -q "_resolve_secret_key" web/app.py
grep -q "\.fw-secret-key" web/app.py
grep -q "\.fw-secret-key" .gitignore
python3 -c "from web.app import create_app; a=create_app(); b=create_app(); assert a.secret_key == b.secret_key, 'key not stable across invocations'"

## Recommendation

**Recommendation:** GO

**Rationale:** Root cause is a missing persistence layer in `web/app.py:47-55`. The fix pattern is already proven upstream in termlink (commit `0373828e`), verified stable across restarts, and scope is minimal (one helper function, ~20 lines, one test). Matches all "GO if" criteria: root cause identified, fix bounded and reversible.

**Evidence:**
- `web/app.py:47-55` auto-generates a new key via `secrets.token_hex(32)` when `Config.SECRET_KEY` is unset. No persistence.
- Session cookies at `session["_csrf_token"]` (app.py:63-65) are signed with `secret_key`. Key rotation ≡ session invalidation ≡ 403 on next POST.
- termlink@0373828e demonstrates the three-source resolver (env → file → generate) and verified stability across two restart cycles.
- `.context/working/` already exists in all framework deployments (session-state directory).
- Sibling file T-1303 (`web/shared.py` PROJECT_ROOT fallback) has independent scope and is tracked separately.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Root cause is a missing persistence layer in `web/app.py:47-55`. The fix pattern is already proven upstream in termlink (commit `0373828e`), verified stable across restarts, and scope is minimal (one helper function, ~20 lines, one test). Matches all "GO if" criteria: root cause identified, fix bounded and reversible.

Evidence:
- `web/app.py:47-55` auto-generates a new key via `secrets.token_hex(32)` when `Config.SECRET_KEY` is unset. No persistence.
- Session cookies at `session["_csrf_token"]` (app.py:63-65) are signed with `secret_key`. Key rotation ≡ session invalidation ≡ 403 on next POST.
- termlink@0373828e demonstrates the three-source resolver (env → file → generate) and verified stability across two restart cycles.
- `.context/working/` already exists in all framework deployments (session-state directory).
- Sibling file T-1303 (`web/shared.py` PROJECT_ROOT fallback) has independent scope and is tracked separately.

**Date**: 2026-04-18T22:45:57Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T19:40:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:45:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Root cause is a missing persistence layer in `web/app.py:47-55`. The fix pattern is already proven upstream in termlink (commit `0373828e`), verified stable across restarts, and scope is minimal (one helper function, ~20 lines, one test). Matches all "GO if" criteria: root cause identified, fix bounded and reversible.

Evidence:
- `web/app.py:47-55` auto-generates a new key via `secrets.token_hex(32)` when `Config.SECRET_KEY` is unset. No persistence.
- Session cookies at `session["_csrf_token"]` (app.py:63-65) are signed with `secret_key`. Key rotation ≡ session invalidation ≡ 403 on next POST.
- termlink@0373828e demonstrates the three-source resolver (env → file → generate) and verified stability across two restart cycles.
- `.context/working/` already exists in all framework deployments (session-state directory).
- Sibling file T-1303 (`web/shared.py` PROJECT_ROOT fallback) has independent scope and is tracked separately.

### 2026-04-18T22:45:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:45:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Root cause is a missing persistence layer in `web/app.py:47-55`. The fix pattern is already proven upstream in termlink (commit `0373828e`), verified stable across restarts, and scope is minimal (one helper function, ~20 lines, one test). Matches all "GO if" criteria: root cause identified, fix bounded and reversible.

Evidence:
- `web/app.py:47-55` auto-generates a new key via `secrets.token_hex(32)` when `Config.SECRET_KEY` is unset. No persistence.
- Session cookies at `session["_csrf_token"]` (app.py:63-65) are signed with `secret_key`. Key rotation ≡ session invalidation ≡ 403 on next POST.
- termlink@0373828e demonstrates the three-source resolver (env → file → generate) and verified stability across two restart cycles.
- `.context/working/` already exists in all framework deployments (session-state directory).
- Sibling file T-1303 (`web/shared.py` PROJECT_ROOT fallback) has independent scope and is tracked separately.
