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

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | called-by | TODO: describe what this component does |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | called_by | TODO: describe what this component does |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-harvest.yaml`*
*Last verified: 2026-02-20*
