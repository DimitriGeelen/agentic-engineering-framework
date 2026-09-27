# arcs

> Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/arcs.py`

**Tags:** `arcs`, `watchtower`, `t-1662`

## What It Does

## Dependencies (15)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [arcs_index](/docs/generated/web-templates-arcs_index) | renders | Renders /arcs index — list of every arc with focus dot indicator, status badge (in-progress/closed), constituent count, anchor task link, link to arc detail. |
| [arc_detail](/docs/generated/web-templates-arc_detail) | renders | Renders /arcs/<id> detail page — arc metadata, completion stats with G-062 audit-detective threshold call-out (matches T-1656), constituent task table with status badges, section Arc Completion Discipline three-question check inline (in-progress only), fw arc close CLI snippet. |
| [arc_membership-py](/docs/generated/lib-arc_membership) | calls | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [bvp](/docs/generated/web-blueprints-bvp) | calls | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [arc_close](/docs/generated/web-templates-arc_close) | renders | Arc-close form: §ACD demo-mode prompt + confirmation, rendered by arcs.arc_close_surface. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bvp](/docs/generated/web-blueprints-bvp) | registers | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [arc_review](/docs/generated/web-templates-arc_review) | renders | Arc review surface (headline-mechanic box + demo evidence), rendered by arcs.arc_review_surface. |
| [arc_membership-py](/docs/generated/lib-arc_membership) | uses | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [bvp](/docs/generated/web-blueprints-bvp) | uses | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |

## Used By (18)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [arc_membership-py](/docs/generated/lib-arc_membership) | called_by | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |
| `tests/playwright/test_arcs_lifecycle_tabs.py` | called_by | — |
| [test_arcs_renders_without_constituent_field](/docs/generated/tests-playwright-test_arcs_renders_without_constituent_field) | called_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the /arcs/<slug> render contract for arcs that omit the legacy `constituent_tasks:` frontmatter field. Fixture writes a synthetic arc YAML to .context/arcs/, yields, removes on teardown — Watchtower reads filesystem live, no restart needed.  Two tests: - test_arcs_detail_renders_without_constituent_tasks: synthetic   field-less arc → 200 + no "Traceback" + no "Internal Server Error"   + arc name renders. - test_legacy_arc_with_constituent_tasks_still_renders: regression   guard pinning legacy /arcs/arc-grooming still renders.  Re-classifies T-1851's first Human [REVIEW] AC to Agent. The deprecation-banner reading-quality AC remains Human [REVIEW] — doc tone is genuinely subjective. |
| [test_arcs_renders_without_constituent_field](/docs/generated/tests-playwright-test_arcs_renders_without_constituent_field) | rendered_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the /arcs/<slug> render contract for arcs that omit the legacy `constituent_tasks:` frontmatter field. Fixture writes a synthetic arc YAML to .context/arcs/, yields, removes on teardown — Watchtower reads filesystem live, no restart needed.  Two tests: - test_arcs_detail_renders_without_constituent_tasks: synthetic   field-less arc → 200 + no "Traceback" + no "Internal Server Error"   + arc name renders. - test_legacy_arc_with_constituent_tasks_still_renders: regression   guard pinning legacy /arcs/arc-grooming still renders.  Re-classifies T-1851's first Human [REVIEW] AC to Agent. The deprecation-banner reading-quality AC remains Human [REVIEW] — doc tone is genuinely subjective. |
| [test_arcs_kanban](/docs/generated/tests-playwright-test_arcs_kanban) | called_by | T-1904: /arcs kanban — 4-column lifecycle layout replacing T-1853 tabs. |
| [check_render_surface_human_ac_sigpipe](/docs/generated/tests-unit-check_render_surface_human_ac_sigpipe) | tests_by | T-1900: render-surface gate error path used to die with SIGPIPE (exit 141) under set -eo pipefail when `render_surface_files_in \| head -N` produced more lines than head consumed. |
| [audit_stale_slice_reference](/docs/generated/tests-unit-audit_stale_slice_reference) | called_by | T-1975 (L-417 prevention): pin the stale-slice-reference audit check. |
| [audit_stale_slice_reference](/docs/generated/tests-unit-audit_stale_slice_reference) | tests_by | T-1975 (L-417 prevention): pin the stale-slice-reference audit check. |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [approvals](/docs/generated/web-blueprints-approvals) | registered_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [test_arcs_routes](/docs/generated/tests-unit-test_arcs_routes) | uses_by | Unit tests for /arcs and /arcs/<id> routes (T-1662) — Flask test_client pins index empty/populated, detail in-progress with three-question check, detail closed without check, 404 for unregistered, missing-task graceful render. |
| [app](/docs/generated/web-app) | uses_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |
| [approvals](/docs/generated/web-blueprints-approvals) | uses_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-arcs.yaml`*
*Last verified: 2026-05-01*
