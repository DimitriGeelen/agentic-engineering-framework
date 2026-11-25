# check-mcp-egress

> check-mcp-egress — PreToolUse hook (matcher `mcp__.*`): MCP tools that can move data off this host need the operator's approval for each use (T-5394, G-140).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-mcp-egress.sh`

## What It Does

check-mcp-egress — PreToolUse hook (matcher `mcp__.*`): MCP tools that can move data off
this host need the operator's approval for each use (T-5394, G-140).
Origin: 050-email-archive (their T-2570) published the operator's personal data to a
claude.ai artifact through an MCP publish tool, unasked. Bash send verbs were gated
(T-2548, Tier 0); MCP tools reached no gate.
The verdict lives in lib/mcp_egress.py (`check`); classification is data in
policy/mcp-egress.yaml. This wrapper only hands it the payload and FAILS CLOSED: the
matcher routes only MCP tools here, so anything that goes wrong refuses the call.
Exit: 0 allow, 2 refuse.

---
*Auto-generated from Component Fabric. Card: `agents-context-check-mcp-egress.yaml`*
*Last verified: 2026-11-24*
