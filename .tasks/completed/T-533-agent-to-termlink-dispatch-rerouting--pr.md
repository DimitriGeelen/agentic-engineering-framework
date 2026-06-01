---
id: T-533
name: "Agent-to-TermLink dispatch rerouting — PreToolUse hook enforcing TermLink-first for heavy parallel work"
description: >
  Inception: Agent-to-TermLink dispatch rerouting — PreToolUse hook enforcing TermLink-first for heavy parallel work

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [agents/context/check-active-task.sh, agents/context/check-agent-dispatch.sh, agents/context/post-compact-resume.sh, agents/task-create/update-task.sh, bin/fw, lib/dispatch.sh, lib/init.sh]
related_tasks: []
created: 2026-03-23T08:43:03Z
last_update: 2026-04-12T07:56:29Z
date_finished: 2026-04-12T07:56:29Z
---

# T-533: Agent-to-TermLink dispatch rerouting — PreToolUse hook enforcing TermLink-first for heavy parallel work

## Problem Statement

CLAUDE.md §Sub-Agent Dispatch Protocol states: "If you're about to dispatch 3+ Task tool agents that will each produce >1K tokens or edit files, use TermLink dispatch instead." This rule is **behavioral only** — the agent decides whether to follow it. Evidence: T-531 session dispatched 3 Explore agents via Task tool (~270K parent context tokens consumed). Same work via TermLink would cost zero parent context.

The existing `check-dispatch.sh` is PostToolUse (advisory, cannot block). A PreToolUse hook on the Agent tool could structurally enforce the TermLink-first rule by blocking heavy dispatches and requiring either TermLink or explicit approval.

**For whom:** Framework agents managing context budget.
**Why now:** TermLink integration (T-503) is stable. The dispatch protocol is documented but unenforced. Context waste from Task tool overuse is a recurring problem.

## Assumptions

- A-001: PreToolUse hooks can match the `Agent` tool (need to verify Claude Code hook matcher supports this)
- A-002: We can detect "heavy dispatch" from the Agent tool's prompt parameter (length, keywords like "Explore", "research")
- A-003: A simple heuristic (agent count tracking + prompt size) is sufficient — no need for perfect prediction
- A-004: TermLink being optional means the hook must degrade gracefully when TermLink isn't installed

## Exploration Plan

1. **Spike A (20min):** Verify PreToolUse hook can match `Agent` tool — check Claude Code hook matcher syntax
2. **Spike B (30min):** Design detection heuristic — what signals indicate "this should be TermLink"? Options: prompt length >500 chars, 3+ Agent calls in sequence, explicit markers
3. **Spike C (20min):** Design approval flow — `fw dispatch approve` (like tier0 approve) with TTL
4. **Spike D (20min):** Fallback behavior when TermLink not installed — warn vs block

## Technical Constraints

- PreToolUse hook must return JSON with `decision` field (allow/block)
- Cannot inspect other pending tool calls (each PreToolUse fires independently per tool)
- TermLink is optional — hook must not break projects without TermLink installed
- Must not block lightweight single-agent dispatches (quick research, codebase search)

## Scope Fence

**IN scope:**
- PreToolUse hook on Agent tool
- Heuristic for heavy dispatch detection
- Approval mechanism with TTL
- Graceful degradation without TermLink

**OUT of scope:**
- Automatic TermLink dispatch (agent must do this manually)
- Changes to the Agent tool's behavior
- Counting concurrent agents (no shared state between hook invocations)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- PreToolUse hooks can match the Agent tool
- A useful heuristic exists that doesn't over-block lightweight dispatches
- Approval flow is clean and fast

**NO-GO if:**
- Hook matcher cannot target the Agent tool
- No reliable heuristic — too many false positives blocking legitimate quick agents
- TermLink absence makes the hook more annoying than helpful

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Option D: Tier 0-style approval with session counter. PreToolUse on Agent tool, first 2 free, 3rd+ blocked. Graceful degradation when TermLink not installed.

## Decisions

**Decision**: GO

**Rationale**: Option D: Tier 0-style approval with session counter. PreToolUse on Agent tool, first 2 free, 3rd+ blocked. Graceful degradation when TermLink not installed.

**Date**: 2026-03-23T09:21:54Z
## Decision

**Decision**: GO

**Rationale**: Option D: Tier 0-style approval with session counter. PreToolUse on Agent tool, first 2 free, 3rd+ blocked. Graceful degradation when TermLink not installed.

**Date**: 2026-03-23T09:21:54Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-23T09:21:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Option D: Tier 0-style approval with session counter. PreToolUse on Agent tool, first 2 free, 3rd+ blocked. Graceful degradation when TermLink not installed.
- **Research artifact:** `docs/reports/T-533-dispatch-rerouting-research.md`

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-06T22:29:32Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-12T07:56:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-12T07:56:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
