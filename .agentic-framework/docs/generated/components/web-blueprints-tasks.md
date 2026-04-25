# tasks

> Flask blueprint: Tasks

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/tasks.py`

## What It Does

Enum loading from status-transitions.yaml (T-1179, G-038)

### Framework Reference

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Record decisions in Decisions section ONLY when choosing between alternatives
6. Updates section is auto-populated at completion — manual entries optional

*(truncated — see CLAUDE.md for full section)*

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/tasks.html` | renders |
| `web/templates/task_detail.html` | renders |
| `web/subprocess_utils.py` | calls |

## Used By (9)

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

---
*Auto-generated from Component Fabric. Card: `web-blueprints-tasks.yaml`*
*Last verified: 2026-02-20*
