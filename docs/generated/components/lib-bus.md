# bus

> fw bus - Task-scoped result ledger for sub-agent communication

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/bus.sh`

## What It Does

fw bus - Task-scoped result ledger for sub-agent communication
Provides structured, size-gated result storage for sub-agent dispatch.
Results are written as typed YAML envelopes in .context/bus/results/T-XXX/.
Payloads >2KB are auto-moved to .context/bus/blobs/T-XXX/.
This prevents T-073-class context explosions by formalizing the
"write to disk, return path + summary" convention into a protocol.
Commands:
fw bus post --task T-XXX --agent TYPE --summary "text" [--result "text" | --blob PATH]
fw bus read T-XXX [R-NNN]
fw bus manifest T-XXX

### Framework Reference

The result ledger formalizes the "write to disk, return path + summary" convention into a protocol with typed YAML envelopes and automatic size gating. Use it for sub-agent dispatch:

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [dispatch](/docs/generated/lib-dispatch) | calls | fw dispatch subcommand: cross-machine SSH-based result dispatch. Serializes bus envelopes and pipes via SSH to remote fw bus receive. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bus-handler](/docs/generated/agents-context-bus-handler) | read_by | Processes incoming bus messages from the inbox directory. Triggered by systemd.path when files appear in .context/bus/inbox/. Routes typed YAML envelopes to appropriate handlers for sub-agent result management. |
| [lib_bus](/docs/generated/tests-unit-lib_bus) | called-by | Unit tests for bus (24 tests) |
| [lib_bus](/docs/generated/tests-unit-lib_bus) | called_by | Unit tests for bus (24 tests) |
| [lib_bus](/docs/generated/tests-unit-lib_bus) | tests_by | Unit tests for bus (24 tests) |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-bus.yaml`*
*Last verified: 2026-02-20*
