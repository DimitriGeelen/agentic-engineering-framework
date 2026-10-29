# mcp_fixture

> tests/unit/helpers/mcp_fixture.bash — a private framework tree for MCP manifest tests (T-4862)

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/helpers/mcp_fixture.bash`

## What It Does

tests/unit/helpers/mcp_fixture.bash — a private framework tree for MCP manifest tests (T-4862)
load helpers/mcp_fixture
setup()    { mcp_live_guard_begin; mcp_fixture_make; ... }
teardown() { ...; mcp_fixture_cleanup; mcp_live_guard_end; }
WHY. t2293 and t2459 used to emit, edit and delete the live
agents/mcp/framework-mcp-manifest.json and policy/capability-overlay/tool-set.yaml,
restoring them from backups in teardown. The unit suite runs files in parallel
(T-3602), so one file's emit landed inside another's delete-then-check window
(t2293 t3, be.47 checks, T-4861), and a killed run left the repo edited.
WHAT. mcp_fixture_make copies the TRACKED files of bin/, lib/, agents/mcp/ and

---
*Auto-generated from Component Fabric. Card: `tests-unit-helpers-mcp_fixture.yaml`*
*Last verified: 2026-10-28*
