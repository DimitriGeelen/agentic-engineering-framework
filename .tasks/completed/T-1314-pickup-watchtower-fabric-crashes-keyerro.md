---
id: T-1314
name: "Pickup: Watchtower /fabric crashes (KeyError: id) on subsystems.yaml without id key — loader should fall back to name (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1129. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T20:23:58Z
last_update: 2026-04-18T22:48:58Z
date_finished: 2026-04-18T22:48:38Z
---

# T-1314: Pickup: Watchtower /fabric crashes (KeyError: id) on subsystems.yaml without id key — loader should fall back to name (from termlink)

## Problem Statement

`web/blueprints/fabric.py:93` does `{s["id"] for s in subsystems}` and crashes with `KeyError: 'id'` when a consumer project's `.fabric/subsystems.yaml` entries use `name:` as the identifier instead of `id:`. Triggers HTTP 500 on the `/fabric` page.

Source: termlink T-1129 pickup (P-036). Termlink applied a workaround (added `id:` to each entry); we own the framework-side fix.

## Assumptions

1. The docstring of `_load_subsystems` already promises the normalized list-of-dicts shape `[{id, name, ...}]`, so normalization at load time is the canonical fix. Confirmed by reading `web/blueprints/fabric.py:53-73`.
2. No other consumer of `_load_subsystems` requires the un-normalized shape — verified by `grep _load_subsystems` showing only this one call site.
3. Fix is one line at the `return raw` branch: project `name → id` when `id` is absent.

## Exploration Plan

None — RCA done. Build task T-1318 will ship the fix + regression test.

## Technical Constraints

- Must not break entries that DO have `id:` (idempotent — only fill when missing).
- Must keep dict-of-dicts branch unaffected (line 71-72 already produces normalized output).

## Scope Fence

**IN:** One-line fix at `_load_subsystems` to fill `id` from `name` when missing. Bats/pytest regression for both shapes (id-present, name-only).

**OUT:** Schema validation at load time (deferred — would touch every fabric loader); auditing other fabric files for missing-id issues (separate task if needed).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (line numbers verified, sole call site confirmed)
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
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Concrete crash with verified line number (`web/blueprints/fabric.py:93`). Fix is one-line, idempotent, strictly more correct (matches the function's own docstring promise). Risk near zero — entries already having `id:` are unaffected. Build sibling T-1318 ships the fix + regression test.

**Evidence:**
- Confirmed crash site: `web/blueprints/fabric.py:93` `{s["id"] for s in subsystems}`
- Confirmed sole call site of `_load_subsystems`: same file, line 81
- Docstring already promises normalized shape: `_load_subsystems` at lines 53-58
- Termlink P-036 envelope provides reproducible repro path
- Workaround (add `id:`) is reasonable but every consumer would need to do it; framework-side fix is the right level

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

Rationale: Concrete crash with verified line number (`web/blueprints/fabric.py:93`). Fix is one-line, idempotent, strictly more correct (matches the function's own docstring promise). Risk near zero — entries already having `id:` are unaffected. Build sibling T-1318 ships the fix + regression test.

Evidence:
- Confirmed crash site: `web/blueprints/fabric.py:93` `{s["id"] for s in subsystems}`
- Confirmed sole call site of `_load_subsystems`: same file, line 81
- Docstring already promises normalized shape: `_load_subsystems` at lines 53-58
- Termlink P-036 envelope provides reproducible repro path
- Workaround (add `id:`) is reasonable but every consumer would need to do it; framework-side fix is the right level

**Date**: 2026-04-18T22:48:58Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T21:04:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:48:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete crash with verified line number (`web/blueprints/fabric.py:93`). Fix is one-line, idempotent, strictly more correct (matches the function's own docstring promise). Risk near zero — entries already having `id:` are unaffected. Build sibling T-1318 ships the fix + regression test.

Evidence:
- Confirmed crash site: `web/blueprints/fabric.py:93` `{s["id"] for s in subsystems}`
- Confirmed sole call site of `_load_subsystems`: same file, line 81
- Docstring already promises normalized shape: `_load_subsystems` at lines 53-58
- Termlink P-036 envelope provides reproducible repro path
- Workaround (add `id:`) is reasonable but every consumer would need to do it; framework-side fix is the right level

### 2026-04-18T22:48:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:48:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete crash with verified line number (`web/blueprints/fabric.py:93`). Fix is one-line, idempotent, strictly more correct (matches the function's own docstring promise). Risk near zero — entries already having `id:` are unaffected. Build sibling T-1318 ships the fix + regression test.

Evidence:
- Confirmed crash site: `web/blueprints/fabric.py:93` `{s["id"] for s in subsystems}`
- Confirmed sole call site of `_load_subsystems`: same file, line 81
- Docstring already promises normalized shape: `_load_subsystems` at lines 53-58
- Termlink P-036 envelope provides reproducible repro path
- Workaround (add `id:`) is reasonable but every consumer would need to do it; framework-side fix is the right level
