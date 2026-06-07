# config

> Watchtower /config page — show all FW_* settings with current values and sources

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/config.html`

## What It Does

### Framework Reference

4-tier resolution: explicit CLI flag > `FW_*` env var > `.framework.yaml` > hardcoded default. Persistent per-project config: `fw config set KEY VALUE` writes to `.framework.yaml`.

Agent-relevant settings:
- `FW_CONTEXT_WINDOW` (300000) — budget enforcement ceiling
- `FW_PORT` (3000) — Watchtower listen port (also resolved via triple-file; see Watchtower Port section)
- `FW_SAFE_MODE` (0) — bypass task gate (escape hatch)
- `FW_DISPATCH_LIMIT` (2) — Agent tool cap before TermLink gate
- `FW_STALE_ARC_DAYS` (30) — T-1855: stale-arc audit WARN threshold. In-progress arcs whose constituent tasks

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/web-blueprints-config) | renders | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [config](/docs/generated/lib-config) | reads | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [base](/docs/generated/web-templates-base) | renders | Template: {{ page_title \| default("Watchtower") }} — Agentic Engineering Framework |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/web-blueprints-config) | rendered_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |

## Related

### Tasks
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-895: Update Watchtower config page template for .framework.yaml source
- T-901: Add project info section to Watchtower /config page

---
*Auto-generated from Component Fabric. Card: `web-templates-config.yaml`*
*Last verified: 2026-04-04*
