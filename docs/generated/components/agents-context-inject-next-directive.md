# inject-next-directive

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/inject-next-directive.py`

## What It Does

T-2367 (S5): first task reference in a directive, used to resolve the
"planned next action" when the directive has no explicit `next_task:` field.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | called_by | Session Resume Hook — Reinject structured context on session recovery |
| [continuous_loop](/docs/generated/tests-integration-continuous_loop) | called_by | TODO: describe what this component does |
| [continuous_loop](/docs/generated/tests-integration-continuous_loop) | tests_by | TODO: describe what this component does |
| [test_inject_next_directive](/docs/generated/tests-unit-test_inject_next_directive) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-inject-next-directive.yaml`*
*Last verified: 2026-06-13*
