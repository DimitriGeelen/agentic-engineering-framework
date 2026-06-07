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

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [check-tier0](/docs/generated/agents-context-check-tier0) | called_by | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [lib_notify](/docs/generated/tests-unit-lib_notify) | called-by | Unit tests for notify (7 tests) |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [lib_notify](/docs/generated/tests-unit-lib_notify) | called_by | Unit tests for notify (7 tests) |
| [pending](/docs/generated/lib-pending) | called_by | TODO: describe what this component does |
| [lib_notify](/docs/generated/tests-unit-lib_notify) | tests_by | Unit tests for notify (7 tests) |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-notify.yaml`*
*Last verified: 2026-03-29*
