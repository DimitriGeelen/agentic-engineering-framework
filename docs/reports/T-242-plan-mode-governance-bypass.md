# T-242: Plan Mode Governance Bypass — Investigation & Resolution

**Task:** T-242
**Date:** 2026-02-22
**Type:** Investigation + Build

## Problem Statement

Claude Code's built-in `EnterPlanMode` tool bypasses ALL framework governance:

1. **No task gate** — planning/research begins without creating a task
2. **No research artifact** — no `docs/reports/T-XXX-*.md` is saved (C-001 violation)
3. **Session Start Protocol skipped** — no `fw context init`, no LATEST.md read
4. **Instruction override** — plan mode's injected system prompt says "This supercedes any other instructions", overriding CLAUDE.md
5. **Untracked artifacts** — plan files go to `.claude/plans/` (ephemeral, untracked) instead of `docs/plans/` (framework-managed)
6. **Execution bias** — after exiting plan mode, the "Implement the following plan:" prompt creates bias that skips commit cadence, task updates, and check-ins

## Evidence: T-241 Implementation

T-241 was implemented via plan mode. Observed governance violations:

- Entered plan mode without `fw context init`
- Skipped reading LATEST.md handover
- Implemented all 7 steps in one batch (no commit cadence)
- No task updates recorded during work
- No check-ins with user between commits
- The **only** gate that fired was `check-active-task.sh` blocking the first Write/Edit (Tier 1)
- Everything before that edit (all research, all planning) was ungoverned

## Investigation: Can We Hook EnterPlanMode?

**Two conflicting signals:**

1. `EnterPlanMode` IS defined as a tool in the function schema (same as Write, Bash, etc.)
2. Claude Code documentation lists PreToolUse firing for: Bash, Edit, Write, Read, Glob, Grep, Task, WebFetch, WebSearch, MCP tools — **EnterPlanMode not listed**

**Conclusion:** Unknown. Must test empirically after session restart (hooks snapshot at session start).

**Available hook events reviewed:** SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, PostToolUseFailure, Notification, SubagentStart, SubagentStop, Stop, TaskCompleted, ConfigChange, PreCompact, SessionEnd — no PlanMode-specific event exists.

## What Plan Mode Overrides

| Framework Rule | How Plan Mode Overrides It |
|---|---|
| Core Principle: "Nothing without a task" | No task required to enter plan mode |
| Session Start Protocol (6 steps) | Completely skipped |
| Research artifact first (C-001) | Plan file in `.claude/plans/`, not `docs/reports/` |
| Instruction Precedence: "framework rules take absolute precedence" | Plan mode prompt says "supercedes any other instructions" |
| Commit cadence rule | Plan mode is read-only; post-plan execution skips cadence |
| Task Updates section | Not updated during plan or execution |

## Existing Framework Alternative

`/plan` skill (`.claude/commands/plan.md`):
- Requires active task (line 8 prerequisite)
- Writes to `docs/plans/{date}-{task-slug}.md` (tracked)
- States "Does ONE thing: plan. No skill chaining."
- Respects framework governance

## Solution: Multi-Layer Defense

### Layer 1: CLAUDE.md Prohibition (agent discipline — primary)

Added `## Plan Mode Prohibition` section to CLAUDE.md before Session Start Protocol. Explicit prohibition of `EnterPlanMode` with rationale and redirect to `/plan`.

**Why this works:** CLAUDE.md is loaded into the agent's context BEFORE any tool invocation. The agent reads the prohibition and should not call `EnterPlanMode`. This fires before plan mode's override prompt can take effect.

### Layer 2: PreToolUse Hook (structural — experimental)

Added to `.claude/settings.json`:
- Matcher: `EnterPlanMode`
- Script: `agents/context/block-plan-mode.sh`
- Behavior: prints error message to stderr, exits with code 2 (BLOCKED)

**If PreToolUse fires for EnterPlanMode:** Structurally prevents plan mode entry.
**If PreToolUse doesn't fire:** Falls back to Layer 1 (CLAUDE.md prohibition).

### Layer 3: Gap Registration (tracking)

Registered G-014 in `gaps.yaml` — "Built-in EnterPlanMode bypasses all framework governance". Status: watching. Trigger: test hook after next session restart.

## Decision

**Chose:** Three-layer defense (CLAUDE.md + hook + gap tracking)
**Why:** Cannot confirm hook works for mode-transition tools until empirical test. Layered approach covers both outcomes.
**Rejected:**
- CLAUDE.md only — insufficient, T-241 showed agent ignores CLAUDE.md when plan mode's override prompt activates
- Hook only — might not fire for EnterPlanMode (unconfirmed)
- Disabling plan mode via Claude Code config — no such configuration option exists

## Files Modified

| File | Change |
|---|---|
| `CLAUDE.md` | Added `## Plan Mode Prohibition` section (~15 lines) |
| `.claude/settings.json` | Added PreToolUse matcher for EnterPlanMode |
| `agents/context/block-plan-mode.sh` | **NEW** — blocking script (exit 2) |
| `.context/project/gaps.yaml` | Registered G-014 |
| `docs/reports/T-242-plan-mode-governance-bypass.md` | **NEW** — this research artifact |

## Open Question

After session restart, does `PreToolUse` fire for `EnterPlanMode`? If yes → G-014 can be closed. If no → Layer 1 (CLAUDE.md prohibition) is the only defense, and we should evaluate whether UserPromptSubmit could intercept plan-mode-triggering prompts.
