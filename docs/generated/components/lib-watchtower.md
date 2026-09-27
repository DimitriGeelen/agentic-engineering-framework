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

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (16)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-tier0](/docs/generated/agents-context-check-tier0) | called_by | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [verify-acs](/docs/generated/lib-verify-acs) | called_by | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [watchtower](/docs/generated/bin-watchtower) | called_by | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | called_by | T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on the identity-verified resolver, never on a default-port `/health` curl. |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | tests_by | T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on the identity-verified resolver, never on a default-port `/health` curl. |
| [t2922_greenfield_first_inception](/docs/generated/tests-integration-t2922_greenfield_first_inception) | called_by | T-2922 — a fresh `fw init` project must be able to complete its first inception with no Watchtower running. |
| [t2922_greenfield_first_inception](/docs/generated/tests-integration-t2922_greenfield_first_inception) | tests_by | T-2922 — a fresh `fw init` project must be able to complete its first inception with no Watchtower running. |
| [t3054_watchtower_root_fallback](/docs/generated/tests-unit-t3054_watchtower_root_fallback) | called_by | T-3054 — the PROJECT_ROOT -> FRAMEWORK_ROOT fallback must be audible, and the identity check must not compute its expected value from the same expression. |
| [t3054_watchtower_root_fallback](/docs/generated/tests-unit-t3054_watchtower_root_fallback) | tests_by | T-3054 — the PROJECT_ROOT -> FRAMEWORK_ROOT fallback must be audible, and the identity check must not compute its expected value from the same expression. |
| [watchtower_url_no_guess](/docs/generated/tests-unit-watchtower_url_no_guess) | tests_by | T-2802 — `fw watchtower url` must not answer with a guess. |
| [arc](/docs/generated/lib-arc) | called_by | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [review](/docs/generated/lib-review) | called_by | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [t3379_review_placeholder_foreign_port](/docs/generated/tests-unit-t3379_review_placeholder_foreign_port) | tests_by | T-3379 — the "Watchtower not running" placeholder must never name a port that something else already holds. |

---
*Auto-generated from Component Fabric. Card: `lib-watchtower.yaml`*
*Last verified: 2026-04-12*
