# config

> Watchtower /config page — show all FW_* settings with current values and sources

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/config.html`

## What It Does

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

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/blueprints/config.py` | renders |
| `lib/config.sh` | reads |
| `web/templates/base.html` | renders |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/config.py` | rendered_by |

## Related

### Tasks
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-895: Update Watchtower config page template for .framework.yaml source
- T-901: Add project info section to Watchtower /config page

---
*Auto-generated from Component Fabric. Card: `web-templates-config.yaml`*
*Last verified: 2026-04-04*
