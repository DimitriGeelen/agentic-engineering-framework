# config

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/config.py`

## What It Does

Known settings registry (mirrors lib/config.sh FW_CONFIG_REGISTRY)

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

---
*Auto-generated from Component Fabric. Card: `web-blueprints-config.yaml`*
*Last verified: 2026-04-03*
