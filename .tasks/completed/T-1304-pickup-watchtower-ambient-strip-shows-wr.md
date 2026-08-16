---
id: T-1304
name: "Pickup: Watchtower ambient strip shows wrong task as focus — ignores focus.yaml
  (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1127. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T18:43:38Z
last_update: '2026-08-16T22:24:28Z'
date_finished: 2026-04-18T22:46:39Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] Problem statement validated
- [x] Assumptions tested (T-1308 build + 4 regression tests confirm)
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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Surgical one-function edit. Fix pattern already proven upstream in termlink@T-1127. No architectural risk, no new dependencies, fully reversible.

Evidence:
- `web/shared.py:93-102` reads `active_dir.glob("T-.md")` sorted alphabetically, ignoring `focus.yaml` entirely.
- `.context/working/focus.yaml` is the canonical focus source (written by `fw work-on`, `fw task update`). Every other surface in the framework respects it.
- Termlink ran the same fix under their T-1127 and confirmed ambient strip now follows `fw work-on`.

**Date**: 2026-04-18T22:47:02Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T19:52:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:46:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Surgical one-function edit. Fix pattern already proven upstream in termlink@T-1127. No architectural risk, no new dependencies, fully reversible.

Evidence:
- `web/shared.py:93-102` reads `active_dir.glob("T-.md")` sorted alphabetically, ignoring `focus.yaml` entirely.
- `.context/working/focus.yaml` is the canonical focus source (written by `fw work-on`, `fw task update`). Every other surface in the framework respects it.
- Termlink ran the same fix under their T-1127 and confirmed ambient strip now follows `fw work-on`.

### 2026-04-18T22:46:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:47:02Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Surgical one-function edit. Fix pattern already proven upstream in termlink@T-1127. No architectural risk, no new dependencies, fully reversible.

Evidence:
- `web/shared.py:93-102` reads `active_dir.glob("T-.md")` sorted alphabetically, ignoring `focus.yaml` entirely.
- `.context/working/focus.yaml` is the canonical focus source (written by `fw work-on`, `fw task update`). Every other surface in the framework respects it.
- Termlink ran the same fix under their T-1127 and confirmed ambient strip now follows `fw work-on`.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ba93ac86
- **Timestamp:** 2026-06-02T14:56:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
