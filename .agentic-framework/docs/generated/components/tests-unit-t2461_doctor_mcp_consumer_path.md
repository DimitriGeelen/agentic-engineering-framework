# t2461_doctor_mcp_consumer_path

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2461_doctor_mcp_consumer_path.bats`

## What It Does

T-2461: fw doctor's framework-MCP-manifest check resolved its asset paths
against $PROJECT_ROOT, which is the CONSUMER root in a vendored install — the
manifest actually lives under $FRAMEWORK_ROOT (.agentic-framework/agents/mcp/).
Result: doctor SKIPped misleadingly on every consumer ("manifest absent — run:
fw mcp emit-manifest"), even though the manifest is present (vendored) and
emit-manifest can't run there (no tool-set.yaml).
Fix: asset paths use ${FRAMEWORK_ROOT:-$PROJECT_ROOT}; the runtime pid file
stays on $PROJECT_ROOT. In the framework repo FRAMEWORK_ROOT==PROJECT_ROOT so
this is a no-op (no regression); in a consumer it resolves the vendored path.
These are fast checks: a source-pin on bin/fw + a behavioral replay of the

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [manifest](/docs/generated/agents-mcp-manifest) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2461_doctor_mcp_consumer_path.yaml`*
*Last verified: 2026-06-22*
