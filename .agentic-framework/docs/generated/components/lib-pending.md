# pending

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/pending.sh`

## What It Does

fw pending - Pending-updates registry (T-1268 B1)
Append-only ledger of cross-project / cross-machine actions an agent could
not complete in-session. Resolved entries are flagged, not deleted.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |

---
*Auto-generated from Component Fabric. Card: `lib-pending.yaml`*
*Last verified: 2026-04-23*
