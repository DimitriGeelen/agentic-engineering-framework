# upgrade_fresh_machine_simulation

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/upgrade_fresh_machine_simulation.bats`

## What It Does

T-1635: fresh-machine simulation guard for fw upgrade.
Validates that fw upgrade works end-to-end on a "fresh-from-vendor"
consumer — only .agentic-framework/ + .framework.yaml, no /opt/999
source-of-truth nearby, no ~/.local/bin/fw shim, scrubbed PATH.
Slim slice (no docker required, runs in any bats environment):
- tempdir = simulated "fresh machine"
- upstream bare repo locally = simulated "tagged framework release"
- consumer = vendored .agentic-framework/ + .framework.yaml
- scrubbed env (no FRAMEWORK_ROOT / PROJECT_ROOT, minimal PATH)
- invoke consumer's vendored bin/fw upgrade as a subprocess

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | tests | TODO: describe what this component does |
| [master-guard](/docs/generated/agents-git-lib-master-guard) | tests | TODO: describe what this component does |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-upgrade_fresh_machine_simulation.yaml`*
*Last verified: 2026-05-14*
