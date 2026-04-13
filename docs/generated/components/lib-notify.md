# notify

> Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/notify.sh`

**Tags:** `ntfy`, `notifications`, `alerts`

## What It Does

Framework push notification helper — thin wrapper over skills-manager alert dispatcher (T-708)
Sends push notifications for framework events (Tier 0 blocks, task completions,
audit failures, handovers, human AC ready). Uses the skills-manager (150) ntfy
infrastructure via its alert dispatcher CLI.
Usage:
source "$FRAMEWORK_ROOT/lib/notify.sh"
fw_notify "title" "message" [trigger] [category]
Configuration:
NTFY_ENABLED — set to "true" to enable (default: disabled)
Design: Fire-and-forget, backgrounded, never blocks the calling script.

## Used By (7)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `agents/context/check-tier0.sh` | called_by |
| `agents/task-create/update-task.sh` | called_by |
| `agents/audit/audit.sh` | called_by |
| `tests/unit/lib_notify.bats` | called-by |
| `agents/handover/handover.sh` | called_by |
| `tests/unit/lib_notify.bats` | called_by |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-notify.yaml`*
*Last verified: 2026-03-29*
