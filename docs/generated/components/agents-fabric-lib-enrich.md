# enrich

> TODO: describe what this component does

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/enrich.py`

## What It Does

YAML helpers

## Dependencies (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [govd_policy](/docs/generated/lib-govd_policy) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [yield-point](/docs/generated/agents-dispatch-yield-point) | calls | TODO: describe what this component does |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [pause](/docs/generated/lib-pause) | calls | TODO: describe what this component does |
| [worktree](/docs/generated/lib-worktree) | calls | TODO: describe what this component does |
| [check-inception-schema](/docs/generated/agents-context-check-inception-schema) | calls | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t2457_fabric_atomic_card_write](/docs/generated/tests-unit-t2457_fabric_atomic_card_write) | tests_by | TODO: describe what this component does |
| [test_enrich_unresolved_targets](/docs/generated/tests-unit-test_enrich_unresolved_targets) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-enrich.yaml`*
*Last verified: 2026-09-03*
