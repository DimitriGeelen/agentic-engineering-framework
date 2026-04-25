# pl007-scanner

> PostToolUse hook scanning Bash output for bare-command leakage patterns (PL-007); injects reminder when agent risks relaying raw commands to user instead of using fw task review / termlink inject push-channels

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/pl007-scanner.sh`

**Tags:** `hook`, `posttool`, `governance`

## What It Does

PL-007 Scanner — PostToolUse hook that flags bare command patterns in Bash output
When a Bash tool result contains text that looks like a command the agent might
relay verbatim to the user (e.g. `fw inception decide T-XXX go`), inject a
reminder that PL-007 says: DO NOT output bare commands; execute them or use the
push-based delivery channel (fw task review / termlink inject).
Detection strategy:
1. Only fires for Bash tool calls.
2. Skips when the agent's own command string already contains the pattern
(i.e. the agent ran `fw inception decide ...` — not relaying, executing).
3. Skips when the command being run is `fw task review` (legitimate precursor

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `.claude/settings.json` | registered_in |

---
*Auto-generated from Component Fabric. Card: `agents-context-pl007-scanner.yaml`*
*Last verified: 2026-04-24*
