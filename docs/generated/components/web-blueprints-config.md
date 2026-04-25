# config

> Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/config.py`

## What It Does

Known settings registry (mirrors lib/config.sh FW_CONFIG_REGISTRY)

### Framework Reference

4-tier resolution: explicit CLI flag > `FW_*` env var > `.framework.yaml` > hardcoded default. Persistent per-project config: `fw config set KEY VALUE` writes to `.framework.yaml`.

Agent-relevant settings:
- `FW_CONTEXT_WINDOW` (300000) — budget enforcement ceiling
- `FW_PORT` (3000) — Watchtower listen port (also resolved via triple-file; see Watchtower Port section)
- `FW_SAFE_MODE` (0) — bypass task gate (escape hatch)
- `FW_DISPATCH_LIMIT` (2) — Agent tool cap before TermLink gate

*(truncated — see CLAUDE.md for full section)*

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/config.html` | renders |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `web/templates/config.html` | used-by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/templates/config.html` | rendered_by |

## Related

### Tasks
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-834: Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for Opus 4.6
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-893: Fix Watchtower /config page — add .framework.yaml tier lookup
- T-901: Add project info section to Watchtower /config page

---
*Auto-generated from Component Fabric. Card: `web-blueprints-config.yaml`*
*Last verified: 2026-04-03*
