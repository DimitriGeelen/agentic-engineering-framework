# enforcement

> Flask blueprint: Enforcement

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/enforcement.py`

## What It Does

### Framework Reference

| Tier | Description | Bypass | Implementation |
|------|-------------|--------|----------------|
| 0 | Consequential actions (force push, hard reset, rm -rf /, DROP TABLE) | Human approval via `fw tier0 approve` | PreToolUse hook on Bash (`check-tier0.sh`) |
| 1 | All standard operations (default) | Create task or escalate to Tier 2 | PreToolUse hook on Write/Edit (`check-active-task.sh`) |
| 2 | Human situational authorization | Single-use, mandatory logging | Partial (git --no-verify + bypass log) |
| 3 | Pre-approved categories (health checks, status queries, git-status) | Configured | Spe

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [enforcement](/docs/generated/web-templates-enforcement) | renders | Page template: Enforcement Tiers |
| [hook-config](/docs/generated/hook-config) | calls | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-enforcement.yaml`*
*Last verified: 2026-02-20*
