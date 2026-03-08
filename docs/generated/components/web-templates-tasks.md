# tasks

> Watchtower UI page: Tasks

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/tasks.html`

## What It Does

### Framework Reference

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Record decisions in Decisions section ONLY when choosing between alternatives
6. Updates section is auto-populated at completion — manual entries optional

*(truncated — see CLAUDE.md for full section)*

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/tasks.py` | rendered_by |

## Related

### Tasks
- T-181: Web UI inline editing — edit tasks, docs, and artifacts in-browser
- T-183: Productionize web UI inline editing (T-181 follow-up)

---
*Auto-generated from Component Fabric. Card: `web-templates-tasks.yaml`*
*Last verified: 2026-02-20*
