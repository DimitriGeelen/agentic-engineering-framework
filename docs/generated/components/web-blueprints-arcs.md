# arcs

> Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/arcs.py`

**Tags:** `arcs`, `watchtower`, `t-1662`

## What It Does

## Dependencies (12)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/arcs_index.html` | renders |
| `web/templates/arc_detail.html` | renders |
| `lib/arc_membership.py` | calls |
| `lib/arc.sh` | calls |
| `web/blueprints/bvp.py` | calls |
| `web/templates/arc_close.html` | renders |
| `C-004` | calls |
| `web/blueprints/tasks.py` | calls |
| `bin/fw` | calls |
| `web/blueprints/bvp.py` | registers |
| `web/templates/arc_review.html` | renders |

## Used By (14)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `lib/arc_membership.py` | called_by |
| `tests/playwright/test_arcs_lifecycle_tabs.py` | called_by |
| `tests/playwright/test_arcs_renders_without_constituent_field.py` | called_by |
| `tests/playwright/test_arcs_renders_without_constituent_field.py` | rendered_by |
| `tests/playwright/test_arcs_kanban.py` | called_by |
| `tests/unit/check_render_surface_human_ac_sigpipe.bats` | tests_by |
| `tests/unit/audit_stale_slice_reference.bats` | called_by |
| `tests/unit/audit_stale_slice_reference.bats` | tests_by |
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `web/blueprints/approvals.py` | called_by |
| `web/blueprints/approvals.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-arcs.yaml`*
*Last verified: 2026-05-01*
