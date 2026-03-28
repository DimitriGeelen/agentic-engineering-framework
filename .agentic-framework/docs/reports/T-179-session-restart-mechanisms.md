---
title: "Session Auto-Restart Mechanisms Research"
task: T-179
date: 2026-02-18
status: complete
tags: [auto-restart, session-management, research]
agents: 1 (explore)
experiment: "Agent instructed to write to this file — could not (Explore agents are read-only)"
---

# Session Auto-Restart Mechanisms Research

> **Task:** T-179 | **Date:** 2026-02-18
> **Note:** Written by orchestrator after sub-agent returned results.

---

## 1. Claude Code Built-in Session Flags

Claude Code provides three session resumption mechanisms (no auto-restart):

| Flag | Purpose |
|------|---------|
| `claude -c` / `--continue` | Resume most recent session (90% use case) |
| `claude -r SESSION` | Resume specific session by ID or name |
| `claude --teleport` | Transfer active web session to CLI |
| `--fork-session` | Create new session ID when resuming |

**Critical finding:** There is NO `--auto-restart` flag or native automatic restart.

## 2. Framework's Current Auto-Recovery (T-111)

The framework uses compaction hooks, not wrapper scripts:

1. **PreCompact Hook** (`pre-compact.sh`): Fires at context exhaustion, generates emergency handover (~100ms)
2. **SessionStart Hook** (`post-compact-resume.sh`): Fires on new session with matcher `compact`, auto-injects structured context

This leverages Claude Code's native event system — no external wrapper needed.

## 3. Would `while true; do claude -c; done` Work?

Syntactically yes. **Not recommended** because:
- Cost overhead per restart (API initialization)
- Hidden failures (user doesn't see session boundaries)
- Breaks handover loop (no human feedback between sessions)
- No intelligent gating (restarts even when human decision needed)

## 4. External Tool: claude-auto-resume

GitHub project `terryso/claude-auto-resume` exists — monitors session state and auto-resumes. Worth investigating for patterns but may have the same gating problems.

## 5. Trap / inotifywait / fswatch Patterns

These introduce:
- Race conditions (state changes during monitoring)
- Silent failures (restart fails, no visibility)
- Loss of coordination with Claude Code's internal state

## 6. Recommendation

| Approach | Verdict |
|----------|---------|
| Native wrapper (`while true; do claude -c; done`) | Too blunt — no gating |
| Compaction hooks (current) | Works but tied to compaction (being removed per T-174) |
| Flag-file based (`touch .restart-requested`) | Viable — needs investigation |
| External tool (claude-auto-resume) | Worth reviewing for patterns |
| **Handover + explicit `claude -c`** | **Simplest, most reliable** |

**Key insight:** With compaction disabled (T-174), the compaction hooks no longer fire. A new mechanism is needed if we want automatic session continuity. The simplest approach is: budget gate forces handover + commit, user runs `claude -c` to continue.

For fully autonomous operation, a flag-file approach could work:
1. Budget gate writes `.context/working/.session-ended`
2. Wrapper script monitors this file
3. On detection: `sleep 2 && claude -c`
4. New session auto-runs `/resume` via SessionStart hook

This needs a separate spike to validate.

## Sources

- [claude-auto-resume (GitHub)](https://github.com/terryso/claude-auto-resume)
- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Claude Code hooks documentation](https://code.claude.com/docs/en/hooks.md)
