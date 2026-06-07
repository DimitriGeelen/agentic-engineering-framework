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

### Framework Reference

**Watchtower's port is per-project, not hard-coded to `3000`.** Two consumer projects on one host would collide if the framework assumed 3000 everywhere.

Resolution order (T-885, T-1287, T-1376):

1. **`.context/working/watchtower.url`** — triple-file source of truth, written by `bin/watchtower.sh` on start. Read this file, don't guess.
2. **`bin/fw config get PORT`** — per-project `FW_PORT` config when no Watchtower is currently running.
3. **`3000`** — default ONLY when neither of the above is available (fresh project, no config, no running instance).

*(truncated — see CLAUDE.md for full section)*

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-tier0](/docs/generated/agents-context-check-tier0) | called_by | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [verify-acs](/docs/generated/lib-verify-acs) | called_by | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [watchtower](/docs/generated/bin-watchtower) | called_by | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |

---
*Auto-generated from Component Fabric. Card: `lib-watchtower.yaml`*
*Last verified: 2026-04-12*
