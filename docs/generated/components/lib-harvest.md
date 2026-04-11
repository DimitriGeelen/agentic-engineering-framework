# harvest

> fw harvest - Collect learnings from projects back into the framework

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/harvest.sh`

## What It Does

fw harvest - Collect learnings from projects back into the framework
Reads a project's .context/ directory and identifies patterns, learnings,
and decisions that could be promoted to the framework level.
Graduation pipeline:
1 project  = local (stays in project)
2+ projects = candidate (proposed for framework)
3+ projects = practice (promoted to framework)

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/lib_harvest.bats` | called-by |
| `tests/unit/lib_harvest.bats` | called_by |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-harvest.yaml`*
*Last verified: 2026-02-20*
