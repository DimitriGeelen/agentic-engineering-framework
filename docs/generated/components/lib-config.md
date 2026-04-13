# config

> Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default

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

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/config.sh` | calls |

## Used By (21)

| Component | Relationship |
|-----------|-------------|
| `lib/verify-acs.sh` | called-by |
| `tests/unit/lib_config.bats` | called-by |
| `web/templates/config.html` | used-by |
| `lib/config.sh` | called-by |
| `agents/context/check-active-task.sh` | called_by |
| `agents/context/check-agent-dispatch.sh` | called_by |
| `agents/context/check-project-boundary.sh` | called_by |
| `agents/context/check-tier0.sh` | called_by |
| `agents/context/pre-compact.sh` | called_by |
| `agents/termlink/termlink.sh` | called_by |
| `C-004` | called_by |
| `bin/fw` | called_by |
| `bin/watchtower.sh` | called_by |
| `C-007` | called_by |
| `C-008` | called_by |
| `lib/keylock.sh` | called_by |
| `lib/config.sh` | called_by |
| `lib/verify-acs.sh` | called_by |
| `tests/unit/lib_config.bats` | called_by |
| `web/templates/config.html` | read_by |
| `agents/git/lib/hooks.sh` | called_by |

## Related

### Tasks
- T-838: ShellCheck sweep — fix warnings across framework bash scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-891: Add .framework.yaml as persistent tier in fw_config resolution
- T-892: Fix fw_config_registry — missing .framework.yaml tier lookup
- T-899: Fix shellcheck SC2015 in lib/config.sh fw_config_registry

---
*Auto-generated from Component Fabric. Card: `lib-config.yaml`*
*Last verified: 2026-04-03*
