# status

> Context Agent - status command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/status.sh`

## What It Does

Context Agent - status command
Shows current context state across all memory types

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context-dispatcher](/docs/generated/context-dispatcher) | called-by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context_status](/docs/generated/tests-unit-context_status) | called_by | Unit tests for context status (7 tests) |
| [context_status](/docs/generated/tests-unit-context_status) | tests_by | Unit tests for context status (7 tests) |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-status.yaml`*
*Last verified: 2026-02-20*
