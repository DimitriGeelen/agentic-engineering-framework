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
- `FW_NTFY_URL` / config `NTFY_URL` (empty) — T-2439: ntfy server base URL for push notifications. Empty = le

*(truncated — see CLAUDE.md for full section)*

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [config](/docs/generated/web-templates-config) | renders | Watchtower /config page — show all FW_* settings with current values and sources |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/web-templates-config) | used-by | Watchtower /config page — show all FW_* settings with current values and sources |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [config](/docs/generated/web-templates-config) | rendered_by | Watchtower /config page — show all FW_* settings with current values and sources |
| [handover_digest](/docs/generated/tests-unit-handover_digest) | tests_by | TODO: describe what this component does |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

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
