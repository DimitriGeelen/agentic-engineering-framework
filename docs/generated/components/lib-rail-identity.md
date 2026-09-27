# rail-identity

> rail-identity.sh — project-scoped signing identity for outbound rail posts (T-2904)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/rail-identity.sh`

## What It Does

rail-identity.sh — project-scoped signing identity for outbound rail posts (T-2904)
WHY THIS EXISTS
`termlink channel post` signs with whatever identity termlink resolves, and on a
host whose ~/.termlink identity is shared across sessions that is the HOST key.
Every co-resident agent then signs identically, so a peer gating on producer
identity cannot tell "AEF posted this" from "something else on AEF's host posted
this". Measured on this host at T-2904: our rail post landed signed as the host
key while the doorbell path signed as the project key — same rail, same peer, two
different producers depending on which code path we happened to use.
The signing key is selected by ENV PRECEDENCE, not by post flags (termlink

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-rail-mcp-label](/docs/generated/agents-context-check-rail-mcp-label) | called_by | T-2908: PreToolUse label gate for the MCP rail-post producer surface. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [rail_identity_guard](/docs/generated/tests-unit-rail_identity_guard) | tests_by | T-2904: outbound rail posts must not be signed by the shared host key. |
| [rail_identity_guard](/docs/generated/tests-unit-rail_identity_guard) | called_by | T-2904: outbound rail posts must not be signed by the shared host key. |

---
*Auto-generated from Component Fabric. Card: `lib-rail-identity.yaml`*
*Last verified: 2026-08-09*
