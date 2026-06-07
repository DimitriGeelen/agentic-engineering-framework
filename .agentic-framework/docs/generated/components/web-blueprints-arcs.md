# arcs

> Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/arcs.py`

**Tags:** `arcs`, `watchtower`, `t-1662`

## What It Does

## Dependencies (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [arcs_index](/docs/generated/web-templates-arcs_index) | renders | Renders /arcs index — list of every arc with focus dot indicator, status badge (in-progress/closed), constituent count, anchor task link, link to arc detail. |
| [arc_detail](/docs/generated/web-templates-arc_detail) | renders | Renders /arcs/<id> detail page — arc metadata, completion stats with G-062 audit-detective threshold call-out (matches T-1656), constituent task table with status badges, section Arc Completion Discipline three-question check inline (in-progress only), fw arc close CLI snippet. |
| [arc_membership-py](/docs/generated/lib-arc_membership) | calls | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [bvp](/docs/generated/web-blueprints-bvp) | calls | TODO: describe what this component does |
| [arc_close](/docs/generated/web-templates-arc_close) | renders | TODO: describe what this component does |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bvp](/docs/generated/web-blueprints-bvp) | registers | TODO: describe what this component does |
| [arc_review](/docs/generated/web-templates-arc_review) | renders | TODO: describe what this component does |

## Used By (14)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [arc_membership-py](/docs/generated/lib-arc_membership) | called_by | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |
| `tests/playwright/test_arcs_lifecycle_tabs.py` | called_by | — |
| [test_arcs_renders_without_constituent_field](/docs/generated/tests-playwright-test_arcs_renders_without_constituent_field) | called_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the /arcs/<slug> render contract for arcs that omit the legacy `constituent_tasks:` frontmatter field. Fixture writes a synthetic arc YAML to .context/arcs/, yields, removes on teardown — Watchtower reads filesystem live, no restart needed.  Two tests: - test_arcs_detail_renders_without_constituent_tasks: synthetic   field-less arc → 200 + no "Traceback" + no "Internal Server Error"   + arc name renders. - test_legacy_arc_with_constituent_tasks_still_renders: regression   guard pinning legacy /arcs/arc-grooming still renders.  Re-classifies T-1851's first Human [REVIEW] AC to Agent. The deprecation-banner reading-quality AC remains Human [REVIEW] — doc tone is genuinely subjective. |
| [test_arcs_renders_without_constituent_field](/docs/generated/tests-playwright-test_arcs_renders_without_constituent_field) | rendered_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the /arcs/<slug> render contract for arcs that omit the legacy `constituent_tasks:` frontmatter field. Fixture writes a synthetic arc YAML to .context/arcs/, yields, removes on teardown — Watchtower reads filesystem live, no restart needed.  Two tests: - test_arcs_detail_renders_without_constituent_tasks: synthetic   field-less arc → 200 + no "Traceback" + no "Internal Server Error"   + arc name renders. - test_legacy_arc_with_constituent_tasks_still_renders: regression   guard pinning legacy /arcs/arc-grooming still renders.  Re-classifies T-1851's first Human [REVIEW] AC to Agent. The deprecation-banner reading-quality AC remains Human [REVIEW] — doc tone is genuinely subjective. |
| [test_arcs_kanban](/docs/generated/tests-playwright-test_arcs_kanban) | called_by | TODO: describe what this component does |
| [check_render_surface_human_ac_sigpipe](/docs/generated/tests-unit-check_render_surface_human_ac_sigpipe) | tests_by | TODO: describe what this component does |
| [audit_stale_slice_reference](/docs/generated/tests-unit-audit_stale_slice_reference) | called_by | TODO: describe what this component does |
| [audit_stale_slice_reference](/docs/generated/tests-unit-audit_stale_slice_reference) | tests_by | TODO: describe what this component does |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [approvals](/docs/generated/web-blueprints-approvals) | registered_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-arcs.yaml`*
*Last verified: 2026-05-01*
