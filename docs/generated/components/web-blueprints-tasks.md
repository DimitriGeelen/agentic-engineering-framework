# tasks

> Flask blueprint: Tasks

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/tasks.py`

## What It Does

T-1980: per-task BVP/Cost computation reused from /bvp and /arcs/<id> helpers.
Same math path → numbers cannot drift between surfaces.

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

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/tasks.html` | renders |
| `web/templates/task_detail.html` | renders |
| `web/subprocess_utils.py` | calls |
| `lib/arc_membership.py` | calls |
| `web/blueprints/bvp.py` | calls |
| `web/blueprints/bvp.py` | registers |

## Used By (22)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/blueprints/approvals.py` | called_by |
| `web/blueprints/approvals.py` | registered_by |
| `web/blueprints/review.py` | called_by |
| `web/blueprints/review.py` | registered_by |
| `web/blueprints/cockpit.py` | called_by |
| `web/blueprints/cockpit.py` | registered_by |
| `tests/playwright/test_api_task_complete.py` | called_by |
| `tests/playwright/test_api_task_inline.py` | called_by |
| `tests/playwright/test_api_task_mutations.py` | called_by |
| `tests/unit/test_ac_body_html_comment.py` | called_by |
| `tests/unit/test_ac_body_html_comment.py` | registered_by |
| `tests/unit/test_file_route_extensions.py` | called_by |
| `tests/playwright/test_landing_arc_cards.py` | called_by |
| `tests/unit/test_arc_membership_web_surfaces.py` | called_by |
| `tests/unit/test_render_surface_gate.bats` | tests_by |
| `tests/playwright/test_landing_arc_cards.py` | rendered_by |
| `web/blueprints/arcs.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-tasks.yaml`*
*Last verified: 2026-02-20*
