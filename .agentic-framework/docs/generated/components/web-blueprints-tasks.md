# tasks

> Flask blueprint: Tasks

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/tasks.py`

## What It Does

T-2222 (OBS-049 full closure): _escape helper for error-fragment renders.
Mirrors the cockpit.py:255 shape; used by the 6 action-error renders at
~L972/990/1006/1022/1045/1061 below to defuse XSS on raw stderr interpolation.

### Framework Reference

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Record decisions in Decisions section ONLY when choosing between alternatives
6. Updates section is auto-populated at completion — manual entries optional

*(truncated — see CLAUDE.md for full section)*

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [tasks](/docs/generated/web-templates-tasks) | renders | Watchtower UI page: Tasks |
| [task_detail](/docs/generated/web-templates-task_detail) | renders | Jinja2 template rendering individual task detail pages in Watchtower. Shows task frontmatter, acceptance criteria with checkboxes, verification commands, decisions, and update history with markdown rendering. |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [arc_membership-py](/docs/generated/lib-arc_membership) | calls | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |
| [bvp](/docs/generated/web-blueprints-bvp) | calls | TODO: describe what this component does |
| [bvp](/docs/generated/web-blueprints-bvp) | registers | TODO: describe what this component does |

## Used By (24)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [approvals](/docs/generated/web-blueprints-approvals) | registered_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [review](/docs/generated/web-blueprints-review) | called_by | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [review](/docs/generated/web-blueprints-review) | registered_by | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [cockpit](/docs/generated/web-blueprints-cockpit) | called_by | Flask blueprint: Cockpit |
| [cockpit](/docs/generated/web-blueprints-cockpit) | registered_by | Flask blueprint: Cockpit |
| [test_api_task_complete](/docs/generated/tests-playwright-test_api_task_complete) | called_by | Playwright tests for task complete API (T-1037). |
| [test_api_task_inline](/docs/generated/tests-playwright-test_api_task_inline) | called_by | Playwright tests for task inline edit API endpoints (T-1029). |
| [test_api_task_mutations](/docs/generated/tests-playwright-test_api_task_mutations) | called_by | Playwright tests for POST task API error handling (T-1026). |
| [test_ac_body_html_comment](/docs/generated/tests-unit-test_ac_body_html_comment) | called_by | TODO: describe what this component does |
| [test_ac_body_html_comment](/docs/generated/tests-unit-test_ac_body_html_comment) | registered_by | TODO: describe what this component does |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | called_by | TODO: describe what this component does |
| [test_landing_arc_cards](/docs/generated/tests-playwright-test_landing_arc_cards) | called_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the landing-page arc-cards render contract and the /tasks?arc=<id> filter contract after the T-1850 arc_id migration. Two tests: - test_landing_arc_cards_show_nonzero_counts: every in-progress arc card   on / renders with a non-zero task count (arc-005 ≥14); no zero-count   cards (the migration-blindness regression signal). - test_tasks_filter_by_arc_returns_members: /tasks?arc=arc-grooming lists   ≥4 known arc-grooming task IDs.  Re-classifies T-1879's Human [REVIEW] AC to Agent. Origin: T-1879 migration-blindness #2 sweep — 5 sites read arc:<slug> tag only after the migration stripped them, surfacing zero arc memberships on the landing page. |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | called_by | TODO: describe what this component does |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | TODO: describe what this component does |
| [test_landing_arc_cards](/docs/generated/tests-playwright-test_landing_arc_cards) | rendered_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the landing-page arc-cards render contract and the /tasks?arc=<id> filter contract after the T-1850 arc_id migration. Two tests: - test_landing_arc_cards_show_nonzero_counts: every in-progress arc card   on / renders with a non-zero task count (arc-005 ≥14); no zero-count   cards (the migration-blindness regression signal). - test_tasks_filter_by_arc_returns_members: /tasks?arc=arc-grooming lists   ≥4 known arc-grooming task IDs.  Re-classifies T-1879's Human [REVIEW] AC to Agent. Origin: T-1879 migration-blindness #2 sweep — 5 sites read arc:<slug> tag only after the migration stripped them, surfacing zero arc memberships on the landing page. |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [test_filter_chips](/docs/generated/tests-unit-test_filter_chips) | called_by | TODO: describe what this component does |
| [test_filter_chips](/docs/generated/tests-unit-test_filter_chips) | registered_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-tasks.yaml`*
*Last verified: 2026-02-20*
