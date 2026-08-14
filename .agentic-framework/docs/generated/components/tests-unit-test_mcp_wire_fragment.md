# test_mcp_wire_fragment

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_mcp_wire_fragment.bats`

## What It Does

T-2272 (arc-010 Slice 2.5): framework-mcp .mcp.json fragment helper.
Surfaces under test:
- agents/mcp/framework-mcp.mcp-fragment.json — static JSON contract
- bin/fw mcp wire-fragment — print verb (cats the file)
- bin/fw mcp help — lists wire-fragment subcommand
AC mapping (per .tasks/active/T-2272-*.md):
Fragment is valid JSON                    — t1
Fragment shape: fw key + cmd+args         — t2 (key renamed framework-mcp→fw, T-2283)
Fragment args path resolves to server     — t3
`wire-fragment` verb prints valid JSON    — t4

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_mcp_wire_fragment.yaml`*
*Last verified: 2026-06-08*
