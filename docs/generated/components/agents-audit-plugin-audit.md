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

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-audit-plugin-audit.yaml`*
*Last verified: 2026-02-20*
