# patterns

> Watchtower UI page: Patterns

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/patterns.html`

## What It Does

### Framework Reference

- **Parallel investigation / audit / enrichment:** 3-5 Task agents scan independent aspects; each writes findings to disk, returns path + summary. Cap at 5 parallel. Use `fw bus post` for formal tracking.
- **Sequential TDD:** Fresh agent per implementation task with review between.
- **TermLink parallel workers:** Spawn TermLink sessions for isolated heavy work. `termlink interact --json` for sync commands, `termlink pty inject/output` for interactive control. Cleanup with `termlink signal SIGTERM` + `termlink clean`. Preferred over Task agents when context isolation matters.

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `C-003` | rendered_by |
| `web/blueprints/discovery.py` | rendered_by |

---
*Auto-generated from Component Fabric. Card: `web-templates-patterns.yaml`*
*Last verified: 2026-02-20*
