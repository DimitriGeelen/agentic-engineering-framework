# fw_costs

> Integration tests for fw costs CLI (4 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/integration/fw_costs.bats`

**Tags:** `fw-costs`, `bats`, `integration-test`

## What It Does

Integration tests for fw costs
Origin: T-947
T-4618: every test owns its HOME and PROJECT_ROOT. fw costs reads
$HOME/.claude/projects/<encoded PROJECT_ROOT>/*.jsonl (lib/paths.sh
fw_claude_project_dirs), so without a fixture the tests measured the
operator's live transcripts and failed on any host without them.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-947: Integration tests for fw costs and fw self-test commands

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_costs.yaml`*
*Last verified: 2026-04-06*
