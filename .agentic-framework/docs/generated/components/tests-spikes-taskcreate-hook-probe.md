# taskcreate-hook-probe

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/spikes/taskcreate-hook-probe.sh`

## What It Does

tests/spikes/taskcreate-hook-probe.sh (T-1115/T-1116)
Verification spike: does Claude Code fire PreToolUse hooks on its
built-in TaskCreate/TaskUpdate/TaskList/TaskGet tools?
This script is a no-op probe: it logs every invocation to
.context/working/.taskcreate-probe.log and exits 0 (allow). Run in a
fresh Claude Code session after merging
tests/spikes/taskcreate-hook-probe-settings-fragment.json into
.claude/settings.json.
If the log fills up after Task* tool calls → A1 (hookability) TRUE
→ proceed with T-1115 Phase 2 Level 1 implementation.

---
*Auto-generated from Component Fabric. Card: `tests-spikes-taskcreate-hook-probe.yaml`*
*Last verified: 2026-04-11*
