---
id: T-1017
name: "Test task pollution — E2E and integration tests leaking task files into real .tasks/active/ directory"
description: >
  Inception: Test task pollution — E2E and integration tests leaking task files into real .tasks/active/ directory

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-07T11:02:23Z
last_update: 2026-04-13T06:23:13Z
date_finished: 2026-04-07T11:16:17Z
---

# T-1017: Test task pollution — E2E and integration tests leaking task files into real .tasks/active/ directory

## Problem Statement

E2E and integration tests created 16 orphan task files in the real `.tasks/active/` directory (T-995 through T-1013), polluting metrics, handovers, and task lists. The framework had no detection or prevention mechanism. Root cause is non-reproducible but the structural blindness is proven.

Research artifact: `docs/reports/T-1017-test-task-pollution.md`

## Assumptions

1. Tests should NEVER write to the real `.tasks/active/` directory
2. A test_helper guard can structurally prevent this
3. An audit check can detect future leaks

## Exploration Plan

1. Reproduce the leak (DONE — not reproducible, isolation code is correct)
2. Identify structural blindness layers (DONE — 5 layers missed it)
3. Evaluate prevention options (DONE — A+B recommended)

## Scope Fence

**IN:** Test isolation validation, audit detection, orphan cleanup
**OUT:** Changing how generate_id() works, modifying the task counter system

## Acceptance Criteria

### Agent
- [x] Problem statement validated — 16 orphan tasks documented with evidence
- [x] Assumptions tested — 5 reproduction attempts, 0 leaks; isolation code confirmed correct
- [x] Recommendation written with rationale — GO with A+B (audit detection + test_helper guard)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1017`
  2. Review research artifact at `docs/reports/T-1017-test-task-pollution.md`
  3. Decide: GO (implement A+B) or NO-GO
  **Expected:** Decision recorded
  **If not:** Ask agent for clarification

## Go/No-Go Criteria

**GO if:**
- Option A+B (audit + test_helper) adds reliable detection and prevention with low complexity
- The 16 orphan tasks can be safely deleted without losing real work

**NO-GO if:**
- Root cause is something that requires a fundamentally different fix
- The orphan tasks contain real work that shouldn't be deleted

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO (Option A+B)

**Rationale:** The root cause is non-reproducible but the structural blindness is proven — 5 detection layers missed 16 orphan tasks. Option A (audit check) catches future leaks. Option B (test_helper guard) prevents them structurally. Both are low-complexity, high-value additions.

**Evidence:**
- 16 orphan tasks with test descriptions ("Test", "Created by E2E test") in real `.tasks/active/`
- 5/5 reproduction attempts showed no leaks — isolation code is correct NOW
- No audit check, .gitignore pattern, or test_helper validation existed
- All orphan task IDs (T-995–T-1013) are sequential with the real project, consuming 16 real IDs
- Framework was blind for unknown duration — discovered only by manual inspection

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO (Option A+B)

Rationale: The root cause is non-reproducible but the structural blindness is proven — 5 detection layers missed 16 orphan tasks. Option A (audit check) catches future leaks. Option B (test_helper guard) prevents them structurally. Both are low-complexity, high-value additions.

Evidence:
- 16 orphan tasks with test descriptions ("Test", "Created by E2E test") in real `.tasks/active/`
- 5/5 reproduction attempts showed no leaks — isolation code is correct NOW
...

**Date**: 2026-04-07T11:16:16Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO (Option A+B)

Rationale: The root cause is non-reproducible but the structural blindness is proven — 5 detection layers missed 16 orphan tasks. Option A (audit check) catches future leaks. Option B (test_helper guard) prevents them structurally. Both are low-complexity, high-value additions.

Evidence:
- 16 orphan tasks with test descriptions ("Test", "Created by E2E test") in real `.tasks/active/`
- 5/5 reproduction attempts showed no leaks — isolation code is correct NOW
...

**Date**: 2026-04-07T11:16:16Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-07T11:02:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-07T11:16:16Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (Option A+B)

Rationale: The root cause is non-reproducible but the structural blindness is proven — 5 detection layers missed 16 orphan tasks. Option A (audit check) catches future leaks. Option B (test_helper guard) prevents them structurally. Both are low-complexity, high-value additions.

Evidence:
- 16 orphan tasks with test descriptions ("Test", "Created by E2E test") in real `.tasks/active/`
- 5/5 reproduction attempts showed no leaks — isolation code is correct NOW
...

### 2026-04-07T11:16:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-07T14:14:08Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-07T15:16:59Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-07T16:40:17Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-07T17:48:15Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-08T07:09:36Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-09T12:42:22Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-09T12:46:40Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-09T12:52:39Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-09T12:58:32Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-12T09:27:15Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-12T11:19:11Z — status-update [task-update-agent]
- **Change:** horizon: next → now

### 2026-04-12T12:21:55Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-12T13:00:27Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-04-12T17:27:20Z — status-update [task-update-agent]
- **Change:** horizon: now → now
