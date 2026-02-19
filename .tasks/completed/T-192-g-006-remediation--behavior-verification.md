---
id: T-192
name: "G-006 remediation — behavior verification gap in P-010 AC gate"
description: >
  The P-010 acceptance criteria gate counts ALL checkboxes in the AC section
  and blocks work-completed if any are unchecked. For tasks with behavior ACs
  (UI/UX criteria like "tapping pause stops mic"), this creates a perverse
  incentive: agents check behavior boxes based on code existence rather than
  observed behavior, because leaving them unchecked blocks completion. The
  framework has no structural distinction between agent-verifiable and
  human-verifiable acceptance criteria.

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [gap, p-010, verification, cross-project]
related_tasks: []
created: 2026-02-19T13:18:27Z
last_update: 2026-02-19T14:53:23Z
date_finished: 2026-02-19T14:53:23Z
---

# T-192: G-006 remediation — behavior verification gap in P-010 AC gate

## Problem Statement

**Origin:** 001-sprechloop project, gap G-006, discovered during T-057 (play/pause button).

The task lifecycle has no distinction between **code-complete** and **behavior-verified**. The P-010 AC gate (update-task.sh lines 163-186) counts all `- [ ]` / `- [x]` lines under `## Acceptance Criteria` and blocks `work-completed` if any are unchecked. This is correct for code-level ACs ("all tests pass") but creates a perverse incentive for behavior ACs ("tapping pause stops mic"):

1. Agent writes code that SHOULD satisfy the behavior AC
2. Agent checks the box based on code existence (honest belief, dishonest verification)
3. P-010 gate passes (8/8 checked)
4. P-011 verification gate passes (tests pass, code exists)
5. Task moves to `completed/` before user has tested anything

**Evidence:** 4 recent sprechloop UI tasks had behavior ACs checked by agent without human verification (T-054: 1, T-055: 2, T-057: 7). Discovered when user asked "is the task status correct?"

**Why now:** This is systemic for ANY project with UI/UX tasks. The framework is the right fix point because P-010 is framework infrastructure.

## Assumptions

- A-014: Most tasks are pure code tasks and will not need the agent/human AC split
- A-015: The agent can correctly categorize ACs at authoring time (agent vs human)
- A-016: Backward compatibility is essential — 188 completed + 2 active tasks must not break

## Exploration Plan

This inception is analysis-and-discussion only (single session). No code changes.

1. Read the full brief and evidence from sprechloop (done)
2. Read the current P-010 implementation in update-task.sh (done)
3. Evaluate all 4 options from the brief independently
4. Present analysis and recommendation to human for discussion
5. Record go/no-go decision

## Technical Constraints

- P-010 gate is in `agents/task-create/update-task.sh` (bash + sed/grep)
- AC parsing uses `sed -n '/^## Acceptance Criteria/,/^## /p'` to extract section
- Then `grep -cE '^\s*-\s*\[[ x]\]'` to count checkboxes
- Task template is `.tasks/templates/default.md`
- 188 completed tasks + 2 active tasks use current format (none use AC headers)
- The fix must work with `PROJECT_ROOT` pattern (shared tooling across projects)

## Scope Fence

**IN scope:**
- Evaluate remediation options for P-010 behavior verification gap
- Assess backward compatibility, implementation effort, structural soundness
- Make recommendation and get human go/no-go

**OUT of scope:**
- Implementation (separate build task after GO)
- Playwright/E2E infrastructure (separate concern, complementary not alternative)
- Changes to P-011 verification gate (orthogonal)

## Acceptance Criteria

- [x] Problem statement validated
- [x] All options evaluated with pros/cons/risks
- [x] Recommendation presented with rationale
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- One option is clearly superior on structural enforcement, backward compat, and effort
- The fix point is confirmed as framework-level (not project-level convention)

**NO-GO if:**
- The problem is better solved per-project (conventions + documentation)
- All structural options have unacceptable backward compatibility costs

## Verification

<!-- Not applicable — inception task, no code changes -->

## Decisions

### 2026-02-19 — Remediation approach for G-006
- **Chose:** Option A (AC tagging) with enhancements
- **Why:** Targets root cause (P-010 can't distinguish AC types), backward compatible, lowest effort, removes perverse incentive structurally
- **Rejected:**
  - Option B (new `code-complete` status) — over-engineered, significant blast radius, doesn't solve P-010 itself
  - Option C (Playwright in P-011) — complementary not solution, high per-task cost, can't cover subjective UX
  - Option D (ownership handoff convention) — already failed on T-057, relies on agent discipline
  - Option E (inline AC prefixes) — more fragile than section headers, easier to forget per-line

### 2026-02-19 — Naming: Agent / Human (not Agent-verifiable / Human-verifiable)
- **Chose:** `### Agent` / `### Human` as section headers
- **Why:** Acknowledges that the boundary is fluid — a behavior AC becomes agent-verifiable when Playwright is added. The naming is about current responsibility, not inherent nature.

### 2026-02-19 — Partial-complete: task stays in active/
- **Chose:** Don't move task to completed/ when human ACs are unchecked
- **Why:** User raised visibility concern — tasks with unchecked human ACs would vanish into completed/. Keeping them in active/ makes them structurally visible in task lists, handovers, and web UI without adding a new status.

### 2026-02-19 — Discoverability: CLI + web UI
- **Chose:** `fw task verify` command + cockpit attention section + task board visual marker
- **Why:** Three layers of visibility (dashboard, CLI, in-context) so human can't miss tasks needing their testing

## Decision

**Decision**: GO

**Rationale**: Option A (AC tagging with ### Agent / ### Human sections) is the clear winner: targets root cause precisely, backward compatible, low effort. Enhanced with partial-complete (task stays in active/ until human ACs checked), CLI query (fw task verify), and web UI cockpit visibility. No new status needed.

**Date**: 2026-02-19T14:52:53Z

## Updates

### 2026-02-19T14:52:53Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Option A (AC tagging with ### Agent / ### Human sections) is the clear winner: targets root cause precisely, backward compatible, low effort. Enhanced with partial-complete (task stays in active/ until human ACs checked), CLI query (fw task verify), and web UI cockpit visibility. No new status needed.

### 2026-02-19T14:53:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
