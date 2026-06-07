# init

> Context Agent - init command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/init.sh`

## What It Does

Context Agent - init command
Initializes working memory for a new session

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [session-metrics](/docs/generated/agents-context-session-metrics) | used-by | Extract per-session quality metrics (CPT, error rate, edit bursts) from JSONL transcript |
| [context-dispatcher](/docs/generated/context-dispatcher) | called-by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [session-metrics](/docs/generated/agents-context-session-metrics) | read_by | Extract per-session quality metrics (CPT, error rate, edit bursts) from JSONL transcript |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [context_init](/docs/generated/tests-unit-context_init) | called_by | Unit tests for context init (16 tests) |
| [context_init](/docs/generated/tests-unit-context_init) | tests_by | Unit tests for context init (16 tests) |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

## Related

### Tasks
- T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-init.yaml`*
*Last verified: 2026-02-20*
