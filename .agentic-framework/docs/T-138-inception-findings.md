# T-138 Inception Findings: Cron-Based Context Budget Monitor

## Problem Statement

The current context budget system (checkpoint.sh as PostToolUse) has fundamental architectural flaws proven by sprechloop cycle 3: 25 emergency handover commits in 10min, circuit breaker bypassed, agent never checked budget once in an entire session at 80% usage.

## Agent 1: Current System Flaw Analysis

**11 flaws identified (3 critical, 3 high, 5 medium):**

### Critical
1. **PostToolUse is agent-controllable** — runs INSIDE agent's execution loop, warnings are just stderr that agent can ignore
2. **Commit counter measures wrong metric** — commits != token consumption. 3 large commits could be 300K tokens
3. **Auto-handover no cooldown** — tokens stay >150K, every tool call re-triggers. Caused 25 commits in 10min (fixed with 10min cooldown, but root cause remains)

### High
4. **Counter reset is agent-controllable** — `echo 0 > .commit-counter` documented in the blocking message itself
5. **Token reading lags 1 API call** — 10-30K behind actual, can exceed threshold before warning
6. **Emergency handover auto-commits without user verification** — violates Authority Model

### Medium
7. Inception gate bypassable via `--no-verify`
8. Handover staleness check ineffective (checks [TODO] count, not content)
9. Tool counter doesn't distinguish tool types (Read vs 20K Bash)
10. Counter reset in init.sh not audit-logged
11. Transcript not found → silent fallback to inaccurate tool counting

### Architectural Root Cause
```
Current:  Agent decides → Tool executes → PostToolUse warns (too late)
Needed:   Cron monitors → PreToolUse checks → BLOCKS before execution
```

## Agent 2: Cron + PreToolUse Design

### Architecture
```
CRON JOB (external, every 30s)        HOOK (PreToolUse, <50ms)
  - Reads JSONL transcripts              - Reads .budget-status file
  - Computes token usage                 - Displays warnings
  - Writes .budget-status                - BLOCKS tool calls at critical
  - Triggers emergency handover          - Agent cannot bypass (exit 2)
```

### File Locations
| File | Purpose |
|------|---------|
| `agents/context/budget-monitor.sh` | Cron job script |
| `agents/context/budget-gate.sh` | PreToolUse hook (~20 lines, fast) |
| `.context/working/.budget-status` | JSON status (written by cron, read by hook) |

### Escalation Ladder
| Level | Tokens | Hook | Cron |
|-------|--------|------|------|
| ok | <100K (<50%) | Silent | Write status |
| warn | 100-130K (50-65%) | Display note | Write status |
| urgent | 130-150K (65-75%) | Display warning | Write status |
| critical | >=150K (75%+) | **BLOCK Write/Edit/Bash** (allow only commit/handover) | Auto-handover with 10min cooldown |

### What to Deprecate
- checkpoint.sh PostToolUse hook → remove from settings
- .tool-counter → remove
- .commit-counter (T-128) → remove from commit-msg and post-commit hooks
- Auto-handover in checkpoint.sh (T-136) → moves to cron job

### Multi-Project Support
- Cron scans `~/.claude/projects/*/` for JSONL files modified in last 10min
- Directory name encodes project path (`-opt-999-...` = `/opt/999/...`)
- Each project gets its own `.budget-status` in `.context/working/`
- `fw context init` writes mapping file for reliable path resolution

### Budget-gate.sh Logic (PreToolUse)
1. Read `.budget-status` (one cat call)
2. Check timestamp — if >90s old, fail-open (cron may be dead)
3. Check level:
   - ok/warn/urgent: exit 0 (allow, with optional warning)
   - critical: check if command is git commit or fw handover → allow; otherwise exit 2 (BLOCK)

### Implementation Sequence
1. Create budget-gate.sh (PreToolUse hook)
2. Create budget-monitor.sh (cron job, extract get_context_tokens logic)
3. Update settings.json (remove PostToolUse checkpoint, add PreToolUse budget-gate)
4. Update init.sh (initialize .budget-status, write mapping file)
5. Remove commit-counter from hooks.sh
6. Update CLAUDE.md
7. Add cron install to fw doctor / fw init
8. Test

## Agent 3: Portability & Constraints

### PreToolUse CAN Block
- Confirmed: exit code 2 = hard block, stderr shown to agent
- Proven by check-active-task.sh and check-tier0.sh already in the framework
- Format: `.claude/settings.json` → `"matcher": "Write|Edit|Bash"` with hook command

### Portability Concern (D4)
- cron: Linux standard
- macOS: needs launchd (different format)
- Non-Claude-Code agents: no hook system at all

### Agent 3 Recommendation: Hybrid
- **Keep PostToolUse hook as fallback** (always works, any platform)
- **Add cron as accuracy supplement** (optional, Linux/macOS)
- If cron stale (>90s): fall back to PostToolUse behavior
- This preserves D4 portability

### Edge Cases Addressed
| Edge Case | Handling |
|-----------|----------|
| Cron not running | Fail-open, fall back to PostToolUse |
| Multiple sessions | Each project gets own .budget-status |
| Agent deletes .budget-status | Cron recreates in ≤30s |
| Transcript not found | Write level: unknown, treat as ok |
| Session ends | Cron skips JSONL not modified in 10+ min |

## Open Questions for Go/No-Go

1. **Pure cron vs hybrid?** Agent 3 recommends hybrid (keep PostToolUse as fallback). Agent 2 proposes pure replacement. Which?
2. **Is cron reliable enough?** If cron dies, system degrades to no monitoring (fail-open) or falls back to PostToolUse (hybrid).
3. **Portability vs effectiveness?** Pure cron is more effective but less portable. Hybrid is portable but complex.
4. **Should we prototype first?** Build budget-gate.sh (the PreToolUse hook) alone as a quick win, then add cron later?

## Decision: PENDING (next session)
