# check-hook-wiring

> check-hook-wiring — PreToolUse hook (matcher Write|Edit|Bash): the operator wires hooks (operator ruling 2026-11-24, T-5403).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-hook-wiring.sh`

## What It Does

check-hook-wiring — PreToolUse hook (matcher Write|Edit|Bash): the operator wires hooks
(operator ruling 2026-11-24, T-5403). An agent's Write/Edit that changes the hook wiring of
.claude/settings.json (or settings.local.json), or a Bash write to those files, is refused;
the agent prepares the change with `fw hook-wiring propose` and hands over the runme.
The verdict lives in lib/hook_wiring.py (`check`). The matcher routes every Write, Edit
and Bash call here, so a crash must not refuse them all: it fails closed only when the
payload names a settings file.
Exit: 0 allow, 2 refuse.

---
*Auto-generated from Component Fabric. Card: `agents-context-check-hook-wiring.yaml`*
*Last verified: 2026-11-24*
