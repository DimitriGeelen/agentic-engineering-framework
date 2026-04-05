# config

> Watchtower /config page — show all FW_* settings with current values and sources

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/config.html`

## What It Does

### Framework Reference

Framework settings follow a 3-tier resolution: explicit CLI flag > `FW_*` env var > hardcoded default.

| Setting | Env Var | Default | Purpose |
|---------|---------|---------|---------|
| Context window | `FW_CONTEXT_WINDOW` | `300000` | Token budget enforcement |
| Dispatch limit | `FW_DISPATCH_LIMIT` | `2` | Agent tool cap before TermLink gate |
| Watchtower port | `FW_PORT` | `3000` | Web UI listen port |
| Safe mode | `FW_SAFE_MODE` | `0` | Bypass task gate (escape hatch) |
| Budget recheck | `FW_BUDGET_RECHECK_INTERVAL` | `5` | Re-read transcript every N calls |
| Status max age | `FW_B

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/blueprints/config.py` | renders |
| `lib/config.sh` | reads |
| `web/templates/base.html` | renders |

---
*Auto-generated from Component Fabric. Card: `web-templates-config.yaml`*
*Last verified: 2026-04-04*
