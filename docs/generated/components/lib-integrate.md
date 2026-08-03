# integrate

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/integrate.py`

## What It Does

── Un-partitionable file taxonomy (T-2397 §3.2) ────────────────────────────
Each class maps to a join strategy that is NOT `git merge`. Order matters:
the first matching rule wins, so put specific paths before broad ones.
A rule is (predicate, class, strategy, needs_human). `needs_human` is the

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t2399_integrate_check](/docs/generated/tests-unit-t2399_integrate_check) | tests_by | TODO: describe what this component does |
| [t2473_union_resolve](/docs/generated/tests-unit-t2473_union_resolve) | called_by | TODO: describe what this component does |
| [t2473_union_resolve](/docs/generated/tests-unit-t2473_union_resolve) | tests_by | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-integrate.yaml`*
*Last verified: 2026-06-14*
