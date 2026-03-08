# enforcement

> Page template: Enforcement Tiers

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/enforcement.html`

## What It Does

### Framework Reference

| Tier | Description | Bypass | Implementation |
|------|-------------|--------|----------------|
| 0 | Consequential actions (force push, hard reset, rm -rf /, DROP TABLE) | Human approval via `fw tier0 approve` | PreToolUse hook on Bash (`check-tier0.sh`) |
| 1 | All standard operations (default) | Create task or escalate to Tier 2 | PreToolUse hook on Write/Edit (`check-active-task.sh`) |
| 2 | Human situational authorization | Single-use, mandatory logging | Partial (git --no-verify + bypass log) |
| 3 | Pre-approved categories (health checks, status queries, git-status) | Configured | Spe

*(truncated — see CLAUDE.md for full section)*

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/enforcement.py` | rendered_by |

---
*Auto-generated from Component Fabric. Card: `web-templates-enforcement.yaml`*
*Last verified: 2026-02-20*
