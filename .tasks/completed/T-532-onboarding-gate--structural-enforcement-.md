---
id: T-532
name: "Onboarding gate — structural enforcement that setup tasks complete before other work"
description: >
  Inception: Onboarding gate — structural enforcement that setup tasks complete before other work

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [agents/context/check-active-task.sh, agents/context/post-compact-resume.sh, agents/task-create/update-task.sh, bin/fw]
related_tasks: []
created: 2026-03-23T08:42:41Z
last_update: 2026-04-12T07:56:26Z
date_finished: 2026-04-12T07:56:26Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-532: Onboarding gate — structural enforcement that setup tasks complete before other work

## Problem Statement

`fw init` creates 5-6 onboarding tasks (T-001 through T-006) with `horizon: now` and `status: started-work`. These tasks configure the project for governed work (health check, first commit, component registration, task lifecycle, handover). **Nothing enforces that these tasks are completed before other work begins.** Claude can skip them entirely — the task gate only checks that *some* task is active, not *which* task.

This means a freshly initialized project can immediately drift into ungoverned work, defeating the purpose of the onboarding sequence. The consumer project (Bilderkarte) showed this working well because the agent happened to follow guidance — not because structure enforced it.

**For whom:** New projects adopting the framework.
**Why now:** The init flow (T-460, T-489) is stable. The gap between "tasks exist" and "tasks are enforced" is the last structural hole in onboarding.

## Assumptions

- A-001: Onboarding tasks have a detectable marker (tag, naming convention, or metadata) that distinguishes them from regular tasks
- A-002: The existing PreToolUse hook pattern (check-active-task.sh) can be extended to check for onboarding completion
- A-003: A simple "all onboarding tasks work-completed" check is sufficient (no need for strict sequencing T-001→T-002→T-003)
- A-004: Users may legitimately need to skip individual onboarding tasks (escape hatch needed)

## Exploration Plan

1. **Spike A (30min):** Review seed task templates — can we add an `onboarding: true` tag or frontmatter field? What marker is least invasive?
2. **Spike B (30min):** Prototype a check in check-active-task.sh — if onboarding tasks exist and are incomplete, block non-onboarding task focus
3. **Spike C (20min):** Design the escape hatch — `fw onboarding skip` or `--force` bypass with logging
4. **Spike D (20min):** Check consumer project evidence — did Bilderkarte actually complete all onboarding tasks, or did some get skipped?

## Technical Constraints

- Must work within PreToolUse hook model (bash, exit 0=allow / exit 2=block)
- Must not break existing projects (backward compatible — no onboarding marker = no gate)
- Must not add significant latency to the hot path (check-active-task.sh runs on every Write/Edit)
- `horizon: immediate` would require changes to handover sorting, resume, and task commands

## Scope Fence

**IN scope:**
- Detection mechanism for onboarding tasks
- PreToolUse gate blocking non-onboarding work
- Escape hatch with logging
- Backward compatibility

**OUT of scope:**
- Strict task sequencing (T-001 before T-002) — soft guidance via Suggested First Action is sufficient
- Generic task dependency system (blocks/blockedBy) — separate concern
- Changes to the Task tool's data model

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- A detectable onboarding marker can be added without breaking existing projects
- The PreToolUse check adds <50ms to the hot path
- The escape hatch is clean (not a hack)

**NO-GO if:**
- No reliable way to distinguish onboarding tasks from regular tasks
- The check adds unacceptable latency
- Backward compatibility requires too many special cases

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Tag-based gate in check-active-task.sh + SessionStart injection. Marker exists on seed templates, backward compatible, minimal change surface. Escape hatch via fw onboarding skip.

## Decisions

**Decision**: GO

**Rationale**: Tag-based gate in check-active-task.sh + SessionStart injection. Marker exists on seed templates, backward compatible, minimal change surface. Escape hatch via fw onboarding skip.

**Date**: 2026-03-23T09:08:49Z
## Decision

**Decision**: GO

**Rationale**: Tag-based gate in check-active-task.sh + SessionStart injection. Marker exists on seed templates, backward compatible, minimal change surface. Escape hatch via fw onboarding skip.

**Date**: 2026-03-23T09:08:49Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-23T09:08:49Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Tag-based gate in check-active-task.sh + SessionStart injection. Marker exists on seed templates, backward compatible, minimal change surface. Escape hatch via fw onboarding skip.
- **Research artifact:** `docs/reports/T-532-onboarding-gate-research.md`

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-06T22:29:31Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-12T07:56:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-12T07:56:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3f969169
- **Timestamp:** 2026-06-02T15:03:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
