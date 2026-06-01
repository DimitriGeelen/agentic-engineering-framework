---
id: T-630
name: "Universal task gate — close Bash, Agent, and TermLink bypass paths that violate core principle"
description: >
  Inception: Universal task gate — close Bash, Agent, and TermLink bypass paths that violate core principle

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-26T22:01:13Z
last_update: 2026-03-27T10:22:30Z
date_finished: 2026-03-27T09:56:28Z
---

# T-630: Universal task gate — close Bash, Agent, and TermLink bypass paths that violate core principle

## Problem Statement

The framework's core principle — "Nothing gets done without a task" — has a 3-tool-wide enforcement keyhole. The task gate (`check-active-task.sh`) only covers `Write|Edit` in PreToolUse hooks. Three wide-open bypass paths exist:

1. **Bash bypass**: `echo`, `sed`, `tee`, `cat <<EOF` can all write files without hitting the task gate. Bash only goes through Tier 0 (destructive commands) and boundary check — not the task gate.
2. **Agent/TaskCreate bypass**: Agent tool (sub-agent dispatch) and TaskCreate have zero PreToolUse gating. An agent can self-authorize by creating a task, setting focus, then passing the Write/Edit gate.
3. **TermLink bypass**: Workers spawned via `fw termlink dispatch` are independent `claude -p` processes. They inherit NO hooks from the parent session. Zero governance propagation.

**Evidence**: T-629 12-agent audit found 27% of session time was governance friction, 90% of completed tasks were meta-work, and the framework has a 28:1 add:remove ratio in CLAUDE.md. T-228 identified 13 bypass vectors. The bypass-log records 78+ Tier 0 bypasses.

**For whom**: Every agent session, every TermLink worker, every sub-agent dispatch.

**Why now**: Without this, the Context Fabric has gaps — work happens unrecorded, episodic memory is incomplete, audit trails have holes. This undermines everything the framework is built on.

## Assumptions

- A-1: Claude Code PreToolUse hooks CAN match on `Bash|Agent|Task` tool names (not just Write/Edit)
- A-2: `check-active-task.sh` can detect file-writing patterns in Bash commands to avoid blocking read-only commands
- A-3: TermLink workers can be given hook configuration via prompt preamble since they don't use settings.json
- A-4: Adding Agent to the task gate won't break sub-agent dispatch (agents are spawned in task context)
- A-5: The safe-command allowlist (git status, ls, curl, fw) is finite and maintainable

## Exploration Plan

1. **Spike 1: Bash file-write detection** (30 min) — Analyze Bash tool input to detect file-writing patterns (`>`, `>>`, `tee`, `sed -i`, `cat <<`). Test with real session data. Determine false-positive rate.
2. **Spike 2: Agent/Task gate feasibility** (15 min) — Add Agent|TaskCreate to PreToolUse matcher, verify check-active-task.sh handles tool inputs without file_path gracefully.
3. **Spike 3: TermLink governance propagation** (30 min) — Design how dispatch preamble can structurally enforce task context. Can we inject a mandatory `--task T-XXX` flag that workers validate?
4. **Spike 4: Safe-command allowlist** (20 min) — Enumerate Bash commands that should always pass (read-only, diagnostic). Design the allowlist pattern.
5. **Spike 5: Recovery path** (15 min) — Ensure the "fix the fixer" deadlock doesn't get worse. Define FW_SAFE_MODE escape hatch for when the expanded gate breaks.

## Technical Constraints

- Claude Code hook semantics: PreToolUse exit 0 = allow, exit 2 = block (stderr shown to agent)
- Hook stdin JSON format: `{"tool_name": "Bash", "tool_input": {"command": "..."}}`
- Hooks snapshot at session start — changes to settings.json require restart
- Must not break existing exempt paths (.context/, .tasks/, .claude/, .git/)
- Must preserve bootstrap mode (fresh projects without .context/ pass through)
- Bash commands have no `file_path` — must parse `command` string for write patterns

## Scope Fence

**IN scope:**
- Expand check-active-task.sh to handle Bash, Agent, TaskCreate tool inputs
- Update settings.json PreToolUse matcher
- Design TermLink governance propagation mechanism
- Define FW_SAFE_MODE safe mode
- Safe-command allowlist for Bash

**OUT of scope:**
- WebFetch gating (low risk, medium effort — separate task)
- PostToolUse enforcement model changes (architectural, separate task)
- Task scope validation (T-469 — already has recommendations)
- CLAUDE.md diet/pruning (T-629 Phase 2 — separate concern)

## Acceptance Criteria

### Agent
- [x] All 5 spikes completed with findings
- [x] Research artifact written at docs/reports/T-630-universal-task-gate.md
- [x] Bash file-write detection pattern tested against real session data (7920 invocations, <0.5% FP)
- [x] Safe-command allowlist defined (27 patterns in 6 categories)
- [x] FW_SAFE_MODE escape hatch designed (env var, 3 lines, Tier 0 stays active)
- [x] Recommendation written with rationale (GO — 3 build tasks)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-630-universal-task-gate.md`
  2. Evaluate: does the Bash gate have acceptable false-positive rate?
  3. Evaluate: does FW_SAFE_MODE provide adequate recovery path?
  4. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-630 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, next step is build tasks
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Bash file-write detection has <5% false positive rate on real session data
- Adding Agent|Bash to PreToolUse matcher doesn't break existing workflows
- FW_SAFE_MODE provides clean recovery when expanded gate causes deadlock
- Safe-command allowlist is finite (<30 patterns) and maintainable

**NO-GO if:**
- Bash command parsing creates more deadlocks than it prevents
- False positive rate >15% (agents constantly blocked on legitimate read-only Bash)
- No viable recovery path exists when the expanded gate itself breaks
- The complexity of universal gating exceeds the value of the enforcement

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: D-016 overturned by D-059, 40 days evidence, safe-command allowlist under 0.5% false-positive

**Date**: 2026-03-27T09:45:08Z
## Decision

**Decision**: GO

**Rationale**: D-016 overturned by D-059, 40 days evidence, safe-command allowlist under 0.5% false-positive

**Date**: 2026-03-27T09:45:08Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T09:45:08Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** D-016 overturned by D-059, 40 days evidence, safe-command allowlist under 0.5% false-positive

### 2026-03-27T09:56:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
