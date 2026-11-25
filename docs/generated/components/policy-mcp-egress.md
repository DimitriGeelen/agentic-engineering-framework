# mcp-egress

> MCP egress policy (T-5394, G-140)

**Type:** config | **Subsystem:** governance | **Location:** `policy/mcp-egress.yaml`

## What It Does

MCP egress policy (T-5394, G-140)
Which MCP tools can move data off this host. The PreToolUse hook
`check-mcp-egress` (matcher `mcp__.*`) reads this file through lib/mcp_egress.py:
egress  — refused unless the OPERATOR approved this one use
(`fw egress approve <tool> --reason "..."`, single use, TTL).
forbidden — publishing to Anthropic (T-5405, operator ruling 2026-11-24): refused
unless config PUBLISH_TO_ANTHROPIC=allow, or the operator approved ONE use
with `fw egress approve <tool> --override-publish-ban --reason "..."`. An
ordinary approval does not open it. (When the key is allow these rules are
skipped and the egress/local rules below apply.)

---
*Auto-generated from Component Fabric. Card: `policy-mcp-egress.yaml`*
*Last verified: 2026-11-24*
