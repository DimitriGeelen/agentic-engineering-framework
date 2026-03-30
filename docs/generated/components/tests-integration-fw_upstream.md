# fw_upstream

> Integration tests for fw upstream CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_upstream.bats`

**Tags:** `bats`, `integration-test`, `upstream`, `cli`

## What It Does

Integration tests for fw upstream subcommand
Tests help, config, status, report guards, list, and error handling.
Network-dependent operations (gh issue create) are tested only in dry-run mode.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

## Related

### Tasks
- T-793: Integration tests for fw upstream, fw build, and fw ask subcommands

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_upstream.yaml`*
*Last verified: 2026-03-30*
