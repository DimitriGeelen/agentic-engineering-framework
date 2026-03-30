# update

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/update.sh`

## What It Does

fw update - Update the framework (vendored or global)
Vendored projects (.agentic-framework/): clones upstream into temp dir,
re-vendors from there. Uses upstream_repo from .framework.yaml.
Global installs (~/.agentic-framework with .git): fetches and resets
to latest upstream (legacy path, pre-T-499).

### Framework Reference

**Location:** `agents/task-create/update-task.sh`

**When to use:** To change task status. Auto-triggers healing diagnosis on `issues`, and finalizes tasks on `work-completed`.

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

## Related

### Tasks
- T-493: fw update command — CLI wrapper for framework self-update
- T-494: Expand fw upgrade — version tracking, context dir sync, E2E test
- T-499: fw update for vendored projects — pull upstream into .agentic-framework/

---
*Auto-generated from Component Fabric. Card: `lib-update.yaml`*
*Last verified: 2026-03-23*
