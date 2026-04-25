# check-agent-dispatch

> Agent Dispatch Gate — PreToolUse hook for Agent tool. Tracks dispatches per session, blocks 3rd+ unless approved or TermLink not installed.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-agent-dispatch.sh`

**Tags:** `enforcement`, `termlink`, `dispatch`

## What It Does

Agent Dispatch Gate — PreToolUse hook for Agent tool
Enforces TermLink-first rule for heavy parallel work (T-533)
CLAUDE.md §Sub-Agent Dispatch Protocol:
"If you're about to dispatch 3+ Task tool agents that will each produce
>1K tokens or edit files, use TermLink dispatch instead."
Enforcement:
1. Tracks Agent dispatches per session via counter file
2. First 2 dispatches: allowed (lightweight use case)
3. 3rd+ dispatch: blocked unless approved or TermLink unavailable
4. Approval via: fw dispatch approve (5-min TTL, like Tier 0)

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `lib/dispatch.sh` | calls |
| `lib/paths.sh` | calls |
| `lib/config.sh` | calls |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-agent-dispatch.yaml`*
*Last verified: 2026-03-23*
