# render_surface

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/render_surface.sh`

## What It Does

lib/render_surface.sh
Render-surface predicate (T-1766, P-013). Decides whether a task touches
the human-review rendering surface — surfaces where what the human sees
depends on layout/CSS/template choices that no deterministic test can
fully capture.
Contract: a "render surface" file is one whose change affects what a
human sees on a Watchtower review/task/inception/approvals page. The
subjective question — "does this look right?" — must be answered by
eyes, not by tests. Tasks touching these files must declare at least
one [REVIEW] Human AC so the human review path catches the visual

---
*Auto-generated from Component Fabric. Card: `lib-render_surface.yaml`*
*Last verified: 2026-05-09*
