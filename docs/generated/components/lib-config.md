# config

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/config.sh`

## What It Does

lib/config.sh — 3-tier configuration resolution
Pattern: explicit arg > FW_* env var > hardcoded default
Usage:
source "$FRAMEWORK_ROOT/lib/config.sh"
CONTEXT_WINDOW=$(fw_config "CONTEXT_WINDOW" 300000)
DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)
Origin: T-817 inception (traceAI pattern adoption), T-819 build

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

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block
- T-834: Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for Opus 4.6
- T-838: ShellCheck sweep — fix warnings across framework bash scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-config.yaml`*
*Last verified: 2026-04-03*
