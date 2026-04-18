---
id: T-1304
name: "Pickup: Watchtower ambient strip shows wrong task as focus — ignores focus.yaml (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1127. Type: bug-report.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T18:43:38Z
last_update: 2026-04-18T19:52:21Z
date_finished: null
---

# T-1304: Pickup: Watchtower ambient strip shows wrong task as focus — ignores focus.yaml (from termlink)

## Problem Statement

`web/shared.py::build_ambient()` picks the first active task (lowest ID, alphabetical) as `focus_task` instead of reading `.context/working/focus.yaml::current_task`. Result: Watchtower ambient strip shows whichever T-XXX file sorts first — not the task the agent is actually working on.

Source: pickup from termlink T-1127. Fix pattern ported from termlink.

## Assumptions

1. `focus.yaml` exists whenever the agent has called `fw work-on` — confirmed (update-task.sh sets it).
2. `current_task: null` is the canonical "no focus" state — confirmed.
3. Falling back to first-active-task when focus is null is acceptable as a degraded mode.

## Exploration Plan

None — fix is surgical. Implementation: load `.context/working/focus.yaml`, read `current_task`, use if non-null; else fall back to existing first-active-task logic.

## Technical Constraints

- Must not crash if `focus.yaml` is missing or malformed — degrade gracefully.
- Reuse existing `load_yaml` helper.

## Scope Fence

**IN:** `build_ambient()` reads `focus.yaml::current_task` before falling back.
**OUT:** Schema validation, multi-task focus, priority queue rendering.

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

grep -q "focus.yaml" web/shared.py
python3 -m pytest tests/web/test_build_ambient.py -q

## Recommendation

**Recommendation:** GO

**Rationale:** Surgical one-function edit. Fix pattern already proven upstream in termlink@T-1127. No architectural risk, no new dependencies, fully reversible.

**Evidence:**
- `web/shared.py:93-102` reads `active_dir.glob("T-*.md")` sorted alphabetically, ignoring `focus.yaml` entirely.
- `.context/working/focus.yaml` is the canonical focus source (written by `fw work-on`, `fw task update`). Every other surface in the framework respects it.
- Termlink ran the same fix under their T-1127 and confirmed ambient strip now follows `fw work-on`.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T19:52:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
