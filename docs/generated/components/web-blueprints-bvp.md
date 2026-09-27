# bvp

> BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a).

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/bvp.py`

## What It Does

PROJECT_ROOT deliberate (T-2648/OBS-097 allowlist): value-drivers.yaml is a
per-project policy INSTANCE seeded from the framework template by
`fw bvp driver --init` (T-2229) — not a framework-owned asset.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bvp](/docs/generated/lib-bvp) | calls | lib/bvp.sh — Business Value Points (BVP) read-only CLI |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [value-drivers](/docs/generated/policy-value-drivers) | calls | BVP value-driver registry (T-1918, arc-006): constitutional directives D1-D4 plus free drivers with weights, rubrics, and retire_when conditions. Drives BVP scoring, ranking, the estimator worker, and the audit retire_when advisory rail. |

## Used By (16)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [arcs](/docs/generated/web-blueprints-arcs) | registered_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [tasks](/docs/generated/web-blueprints-tasks) | called_by | Flask blueprint: Tasks |
| [tasks](/docs/generated/web-blueprints-tasks) | registered_by | Flask blueprint: Tasks |
| [test_driver_rubrics](/docs/generated/tests-unit-test_driver_rubrics) | called_by | T-2084: per-driver 0-5 scoring rubric parser for /bvp slider rows. |
| [test_driver_rubrics](/docs/generated/tests-unit-test_driver_rubrics) | registered_by | T-2084: per-driver 0-5 scoring rubric parser for /bvp slider rows. |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [approvals](/docs/generated/web-blueprints-approvals) | registered_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [test_driver_rubrics](/docs/generated/tests-unit-test_driver_rubrics) | uses_by | T-2084: per-driver 0-5 scoring rubric parser for /bvp slider rows. |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |
| [approvals](/docs/generated/web-blueprints-approvals) | uses_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [arcs](/docs/generated/web-blueprints-arcs) | uses_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [tasks](/docs/generated/web-blueprints-tasks) | uses_by | Flask blueprint: Tasks |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-bvp.yaml`*
*Last verified: 2026-05-19*
