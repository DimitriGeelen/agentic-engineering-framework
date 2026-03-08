# check-active-task

> Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-active-task.sh`

## What It Does

Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools
Blocks file modifications when no active task is set in focus.yaml.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
Receives JSON on stdin with tool_name and tool_input.file_path.
Exempt paths (framework operations that don't need task context):
.context/   — Context fabric management
.tasks/     — Task creation/updates
.claude/    — Claude Code settings

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `C-009` | triggered_by |
| `agents/audit/self-audit.sh` | verified_by |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

## Related

### Tasks
- T-230: Fix MEDIUM severity enforcement bypasses — B-009, B-012, integrity checks
- T-232: Fix task-gate completed-task bypass
- T-244: Pre-edit fabric awareness — advisory dependency check on Write/Edit
- T-288: Document Watchtower LXC deployment topology
- T-354: Tighten task gate: validate status + clear focus on completion

---
*Auto-generated from Component Fabric. Card: `agents-context-check-active-task.yaml`*
*Last verified: 2026-03-01*
