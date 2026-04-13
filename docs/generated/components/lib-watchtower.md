# watchtower

> Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/watchtower.sh`

## What It Does

lib/watchtower.sh — Shared Watchtower URL detection and browser-open helper (T-974, T-1154)
Centralizes port detection, host detection, and browser opening so that
ALL scripts use the same logic. Eliminates hardcoded ports and duplicated
browser-open code.
Usage:
source "$FRAMEWORK_ROOT/lib/watchtower.sh"
url=$(_watchtower_url T-XXX)                    # get base URL with correct port
_watchtower_open "http://host:port/path"         # open in browser (desktop-user aware)
Requires: PROJECT_ROOT (from paths.sh chain), config.sh for fw_config

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `agents/context/check-tier0.sh` | called_by |
| `C-004` | called_by |
| `bin/fw` | called_by |
| `lib/verify-acs.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-watchtower.yaml`*
*Last verified: 2026-04-12*
