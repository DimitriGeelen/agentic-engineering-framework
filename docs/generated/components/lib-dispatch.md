# dispatch

> fw dispatch subcommand: cross-machine SSH-based result dispatch. Serializes bus envelopes and pipes via SSH to remote fw bus receive.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/dispatch.sh`

## What It Does

fw dispatch - SSH-based cross-machine communication
Sends bus envelopes to remote machines via SSH pipe.
Uses ~/.ssh/config for host resolution and authentication.
Commands:
fw dispatch send --host REMOTE --task T-XXX --agent TYPE --summary "text" [--result "text"]
fw dispatch hosts    # List configured SSH hosts
Integration with fw bus:
fw bus post --remote REMOTE --task T-XXX --agent TYPE --summary "text"
Part of: Agentic Engineering Framework (T-517: SSH-based cross-machine comms)

### Framework Reference

**Default: dispatch the work to a TermLink worker. Executing it yourself is the
exception you justify, not the default you fall into.**

The parent session's context is the binding constraint on how much work a day
holds. A TermLink worker costs zero parent context, survives compaction, and runs
observably. Self-execution spends the one resource that cannot be replenished
mid-session.

### The test — can you write the dispatch prompt without doing the work first?

*(truncated — see CLAUDE.md for full section)*

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bus](/docs/generated/lib-bus) | called_by | fw bus - Task-scoped result ledger for sub-agent communication |
| [check-agent-dispatch](/docs/generated/agents-context-check-agent-dispatch) | called_by | Agent Dispatch Gate — PreToolUse hook for Agent tool. Tracks dispatches per session, blocks 3rd+ unless approved or TermLink not installed. |
| [lib_dispatch](/docs/generated/tests-unit-lib_dispatch) | called-by | Unit tests for dispatch (9 tests) |
| [lib_dispatch](/docs/generated/tests-unit-lib_dispatch) | called_by | Unit tests for dispatch (9 tests) |
| [lib_dispatch](/docs/generated/tests-unit-lib_dispatch) | tests_by | Unit tests for dispatch (9 tests) |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-dispatch.yaml`*
*Last verified: 2026-03-23*
