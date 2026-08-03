# bvp

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/bvp.py`

## What It Does

PROJECT_ROOT deliberate (T-2648/OBS-097 allowlist): value-drivers.yaml is a
per-project policy INSTANCE seeded from the framework template by
`fw bvp driver --init` (T-2229) — not a framework-owned asset.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bvp](/docs/generated/lib-bvp) | calls | TODO: describe what this component does |

## Used By (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [arcs](/docs/generated/web-blueprints-arcs) | registered_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [tasks](/docs/generated/web-blueprints-tasks) | called_by | Flask blueprint: Tasks |
| [tasks](/docs/generated/web-blueprints-tasks) | registered_by | Flask blueprint: Tasks |
| [test_driver_rubrics](/docs/generated/tests-unit-test_driver_rubrics) | called_by | TODO: describe what this component does |
| [test_driver_rubrics](/docs/generated/tests-unit-test_driver_rubrics) | registered_by | TODO: describe what this component does |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [approvals](/docs/generated/web-blueprints-approvals) | registered_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-bvp.yaml`*
*Last verified: 2026-05-19*
