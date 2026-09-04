# t3233_arm_bounds

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3233_arm_bounds.bats`

## What It Does

T-3233 — `fw continuous arm` must not report a bound it does not enforce.
arc-012 review findings W1-F2, W1-F3, W1-F4 and W1-F8/W5-F4: four defects in one
verb, all the same shape. `arm` printed a confident summary of a run it had not
actually bounded.
THE CENTRAL TEST is `printed ceiling equals enforced ceiling`. Asserting either
side alone is what let this ship: `arm` printed `Ceiling: tier 5` truthfully —
that IS what it wrote to state — while `inject-next-directive.py:261` resolves
DIRECTIVE-first and used the stale `1` sitting in `.next-directive.yaml`. Both
numbers were individually correct about their own file. Only the comparison is
the defect. Measured on the pre-fix code:

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3233_arm_bounds.yaml`*
*Last verified: 2026-08-31*
