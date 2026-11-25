# t5394_mcp_egress

> T-5394 (G-140) — MCP egress gate: the PreToolUse hook agents/context/check-mcp-egress.sh (matcher `mcp__.*`) refuses MCP tools that can move data off the host unless the operator approved that one use; the approval is operator-only…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5394_mcp_egress.bats`

## What It Does

T-5394 (G-140) — MCP egress gate: the PreToolUse hook agents/context/check-mcp-egress.sh
(matcher `mcp__.*`) refuses MCP tools that can move data off the host unless the
operator approved that one use; the approval is operator-only; classification is data
(policy/mcp-egress.yaml); the hook reaches consumers through `fw init` and `fw upgrade`.
Hermetic: every case runs against a temp PROJECT_ROOT with synthetic payloads. No MCP
tool is ever called.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5394_mcp_egress.yaml`*
*Last verified: 2026-11-24*
