# tasks

> Flask blueprint: Tasks

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/tasks.py`

## What It Does

Helpers — file finding and frontmatter editing (T-181 spike)

### Framework Reference

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Record decisions in Decisions section ONLY when choosing between alternatives
6. Updates section is auto-populated at completion — manual entries optional

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/tasks.html` | renders |
| `web/templates/task_detail.html` | renders |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |

## Related

### Tasks
- T-165: Fix 20 broken Watchtower task links — YAML quoting bugs in task and episodic files
- T-181: Web UI inline editing — edit tasks, docs, and artifacts in-browser

---
*Auto-generated from Component Fabric. Card: `web-blueprints-tasks.yaml`*
*Last verified: 2026-02-20*
