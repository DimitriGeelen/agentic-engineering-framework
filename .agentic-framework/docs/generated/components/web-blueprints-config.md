# config

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/config.py`

## What It Does

Known settings registry (mirrors lib/config.sh FW_CONFIG_REGISTRY)

### Framework Reference

Framework settings follow a 4-tier resolution: explicit CLI flag > `FW_*` env var > `.framework.yaml` > hardcoded default.

Persistent per-project configuration: `fw config set KEY VALUE` writes to `.framework.yaml`.

| Setting | Env Var | Default | Purpose |
|---------|---------|---------|---------|
| Context window | `FW_CONTEXT_WINDOW` | `300000` | Token budget enforcement |
| Dispatch limit | `FW_DISPATCH_LIMIT` | `2` | Agent tool cap before TermLink gate |
| Watchtower port | `FW_PORT` | `3000` | Web UI listen port |
| Safe mode | `FW_SAFE_MODE` | `0` | Bypass task gate (escape hatch) |
|

*(truncated — see CLAUDE.md for full section)*

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/config.html` | renders |

## Used By (4)

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
