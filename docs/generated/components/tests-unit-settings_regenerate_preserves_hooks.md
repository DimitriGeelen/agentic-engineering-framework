# settings_regenerate_preserves_hooks

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/settings_regenerate_preserves_hooks.bats`

## What It Does

T-2710: a forced .claude/settings.json regenerate must not silently delete hooks
that `fw hook-enable` added after init.
generate_claude_code_config (lib/init.sh) writes settings.json from a fixed heredoc
template. With force=true it overwrote unconditionally — so the 6 hooks this repo
added post-init (check-active-completed-dup, check-arc-id, check-heredoc-cmd-sub,
check-inception-decisions, check-inception-schema, check-settings-edit) were wiped
by any `fw upgrade` that took the regenerate branch. Six governance gates off, no
message. T-2709's A2 made that branch reachable on every consumer, which is what
turned a dormant trap into a live one.
Two invariants, and BOTH matter:

---
*Auto-generated from Component Fabric. Card: `tests-unit-settings_regenerate_preserves_hooks.yaml`*
*Last verified: 2026-08-01*
