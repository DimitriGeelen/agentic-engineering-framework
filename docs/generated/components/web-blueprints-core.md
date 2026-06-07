# core

> Flask blueprint: Core

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/core.py`

## What It Does

Active tasks with no recent update — use shared cache

### Framework Reference

**Nothing gets done without a task.** This is enforced structurally by the framework, not by agent discipline.

## Dependencies (15)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [cockpit](/docs/generated/web-blueprints-cockpit) | calls | Flask blueprint: Cockpit |
| [index](/docs/generated/web-templates-index) | renders | Watchtower UI page: Index |
| [cockpit](/docs/generated/web-templates-cockpit) | renders | Page template: Watchtower |
| [project](/docs/generated/web-templates-project) | renders | Watchtower UI page: Project |
| [project_doc](/docs/generated/web-templates-project_doc) | renders | Watchtower UI page: Project Doc |
| [directives](/docs/generated/web-templates-directives) | renders | Watchtower UI page: Directives |
| [cockpit](/docs/generated/web-blueprints-cockpit) | registers | Flask blueprint: Cockpit |
| [context_loader](/docs/generated/web-context_loader) | calls | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [approvals](/docs/generated/web-blueprints-approvals) | calls | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [approvals](/docs/generated/web-blueprints-approvals) | registers | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [costs](/docs/generated/web-blueprints-costs) | calls | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [costs](/docs/generated/web-blueprints-costs) | registers | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [arc_membership-py](/docs/generated/lib-arc_membership) | calls | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |

## Used By (13)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_landing_arc_cards](/docs/generated/tests-playwright-test_landing_arc_cards) | called_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the landing-page arc-cards render contract and the /tasks?arc=<id> filter contract after the T-1850 arc_id migration. Two tests: - test_landing_arc_cards_show_nonzero_counts: every in-progress arc card   on / renders with a non-zero task count (arc-005 ≥14); no zero-count   cards (the migration-blindness regression signal). - test_tasks_filter_by_arc_returns_members: /tasks?arc=arc-grooming lists   ≥4 known arc-grooming task IDs.  Re-classifies T-1879's Human [REVIEW] AC to Agent. Origin: T-1879 migration-blindness #2 sweep — 5 sites read arc:<slug> tag only after the migration stripped them, surfacing zero arc memberships on the landing page. |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | called_by | TODO: describe what this component does |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | registered_by | TODO: describe what this component does |
| [test_landing_arc_cards](/docs/generated/tests-playwright-test_landing_arc_cards) | rendered_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the landing-page arc-cards render contract and the /tasks?arc=<id> filter contract after the T-1850 arc_id migration. Two tests: - test_landing_arc_cards_show_nonzero_counts: every in-progress arc card   on / renders with a non-zero task count (arc-005 ≥14); no zero-count   cards (the migration-blindness regression signal). - test_tasks_filter_by_arc_returns_members: /tasks?arc=arc-grooming lists   ≥4 known arc-grooming task IDs.  Re-classifies T-1879's Human [REVIEW] AC to Agent. Origin: T-1879 migration-blindness #2 sweep — 5 sites read arc:<slug> tag only after the migration stripped them, surfacing zero arc memberships on the landing page. |

## Related

### Tasks
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-blueprints-core.yaml`*
*Last verified: 2026-02-20*
