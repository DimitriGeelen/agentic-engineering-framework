# T-533: Agent-to-TermLink Dispatch Rerouting Research

## Problem
CLAUDE.md dispatch protocol says "use TermLink for 3+ heavy agents" but this is behavioral only. Agents routinely violate it, wasting parent context.

## Evidence
- T-531 session: 3 Explore agents dispatched via Task tool → ~270K parent context tokens consumed
- T-073 (historical): 9 agents returned full content → 177K context spike
- check-dispatch.sh exists but is PostToolUse (advisory, cannot block)

## Agent Research Findings

### Current Enforcement
- `check-dispatch.sh` (PostToolUse on Task|TaskOutput): warns at 5K chars, critical at 20K chars — **cannot block**
- No PreToolUse hook exists for the Agent tool
- CLAUDE.md documents the rule but relies on agent discipline

### Technical Feasibility
- PreToolUse hooks support arbitrary tool matchers — `Agent` should work (same as `Write|Edit|Bash`)
- Hook receives tool input as JSON — can inspect `prompt` parameter for length/keywords
- Cannot count concurrent dispatches (each hook invocation is independent)
- Could use a counter file (like tool-counter) to track dispatches per session

### Design Options

#### Option A: Prompt-length heuristic
- Block Agent dispatches where `prompt` length > 500 chars (heavy research prompts)
- Allow short prompts (quick lookups, file reads)
- **Pro:** Simple, correlates with output size
- **Con:** False positives on detailed but lightweight prompts

#### Option B: Session dispatch counter
- Track Agent dispatches in `.context/working/.dispatch-counter`
- Block 4th+ dispatch without approval (mirrors max 5 parallel rule)
- **Pro:** Directly enforces the parallel limit
- **Con:** Counter resets on compaction, can't distinguish sequential vs parallel

#### Option C: TermLink-availability gate
- If TermLink is installed: block heavy dispatches, suggest TermLink
- If TermLink not installed: warn only (graceful degradation)
- **Pro:** Only enforces when the alternative exists
- **Con:** May encourage not installing TermLink to avoid the gate

#### Option D: Approval-based (like Tier 0)
- All Agent dispatches allowed, but 3rd+ requires `fw dispatch approve`
- Approval has 5-min TTL, logged to bypass-log
- **Pro:** Flexible, mirrors proven Tier 0 pattern
- **Con:** Friction on legitimate multi-agent work

## Decision: GO — Option D (Tier 0-style approval with counter)

**Implementation:**
- `agents/context/check-agent-dispatch.sh` — PreToolUse hook on Agent tool
- Counter tracks dispatches in `.context/working/.agent-dispatch-counter`
- First 2 dispatches free, 3rd+ blocked unless approved or TermLink not installed
- `fw dispatch approve` — 5-min TTL approval (like Tier 0)
- `fw dispatch reset` — reset counter
- Graceful degradation: if TermLink not installed, warn but allow

**Wiring:** Added to `lib/init.sh` settings.json template as 12th hook.
Existing projects need manual addition to `.claude/settings.json`.

## Dialogue Log

- Human noticed 3 background agents used where TermLink should have been
- Human proposed: hook to reroute Agent tool to TermLink, bypass only after approval
- This aligns with the Tier 0 approval pattern — structural gate with escape hatch
