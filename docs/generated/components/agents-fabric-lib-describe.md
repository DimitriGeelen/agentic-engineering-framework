# describe

> Derive a component card's `purpose` and `subsystem` from the source file itself.

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/describe.py`

## What It Does

The exact string register.sh writes. Anything equal to it — or any purpose

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [render_surface](/docs/generated/lib-render_surface) | calls | Render-surface predicate (T-1766, P-013). Decides whether a task touches the human-review rendering surface — surfaces where what the human sees depends on layout/CSS/template choices that no deterministic test can fully capture. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [enrich](/docs/generated/agents-fabric-lib-enrich) | uses_by | Fabric enrichment engine — auto-detect dependency edges from source analysis. |
| [underpopulated](/docs/generated/agents-fabric-lib-underpopulated) | uses_by | Scan component cards for the under-populated class — a card that says nothing. |
| [test_t3430_describe](/docs/generated/tests-unit-test_t3430_describe) | called_by | T-3430 — the fabric card deriver: what a file says about itself, or a refusal. |

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-describe.yaml`*
*Last verified: 2026-09-22*
