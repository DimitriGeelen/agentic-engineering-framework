# plugin-audit

> Scans enabled Claude Code plugins for task-system awareness. Classifies each skill/agent/command as TASK-AWARE, TASK-SILENT, or TASK-OVERRIDING based on framework governance integration.

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/plugin-audit.sh`

## What It Does

Plugin Task-Awareness Audit
T-067: Scans enabled Claude Code plugins for task-system awareness
Classifies each skill/agent/command as:
TASK-AWARE    — References task system (task, fw work-on, TaskCreate, etc.)
TASK-SILENT   — No task references, no authority claims (informational)
TASK-BYPASSING — Authority-claiming language without task gates
Exit codes: 0 = all clear, 1 = bypassing skills found

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-audit-plugin-audit.yaml`*
*Last verified: 2026-02-20*
