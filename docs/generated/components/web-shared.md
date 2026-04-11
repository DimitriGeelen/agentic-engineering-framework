# shared

> Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering)

**Type:** library | **Subsystem:** watchtower | **Location:** `web/shared.py`

**Tags:** `flask`, `web-ui`, `shared`, `navigation`

## What It Does

Path resolution

## Used By (42)

| Component | Relationship |
|-----------|-------------|
| `C-003` | called_by |
| `web/app.py` | called_by |
| `web/blueprints/cockpit.py` | called_by |
| `web/blueprints/core.py` | called_by |
| `web/blueprints/enforcement.py` | called_by |
| `web/blueprints/fabric.py` | called_by |
| `web/blueprints/inception.py` | called_by |
| `web/blueprints/metrics.py` | called_by |
| `web/blueprints/quality.py` | called_by |
| `web/blueprints/risks.py` | called_by |
| `web/blueprints/session.py` | called_by |
| `web/blueprints/tasks.py` | called_by |
| `web/blueprints/timeline.py` | called_by |
| `web/blueprints/api.py` | imported_by |
| `web/blueprints/docs.py` | imported_by |
| `web/blueprints/settings.py` | imported_by |
| `web/search_utils.py` | imported_by |
| `web/blueprints/api.py` | called_by |
| `web/blueprints/approvals.py` | called_by |
| `web/blueprints/cron.py` | called_by |
| `web/blueprints/discoveries.py` | called_by |
| `web/blueprints/docs.py` | called_by |
| `web/blueprints/review.py` | called_by |
| `web/blueprints/settings.py` | called_by |
| `web/embeddings.py` | called_by |
| `web/search.py` | called_by |
| `web/search_utils.py` | called_by |
| `web/blueprints/api.py` | imports_by |
| `web/blueprints/docs.py` | imports_by |
| `web/blueprints/settings.py` | imports_by |
| `web/context_loader.py` | called_by |
| `web/search.py` | imports_by |
| `web/search_utils.py` | imports_by |
| `web/subprocess_utils.py` | called_by |
| `web/blueprints/costs.py` | called-by |
| `web/blueprints/config.py` | called-by |
| `web/blueprints/discovery.py` | called-by |
| `web/blueprints/sessions.py` | called_by |
| `web/blueprints/terminal.py` | called_by |
| `web/blueprints/config.py` | called_by |
| `web/blueprints/costs.py` | called_by |
| `web/blueprints/discovery.py` | called_by |

## Related

### Tasks
- T-851: Linkable task references in handover session summary — clickable T-XXX links to Watchtower task pages
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-984: Add Sessions link to Watchtower navigation

---
*Auto-generated from Component Fabric. Card: `web-shared.yaml`*
*Last verified: 2026-02-20*
