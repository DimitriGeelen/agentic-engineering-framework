# episodic

> Context Agent - generate-episodic command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/episodic.sh`

## What It Does

Context Agent - generate-episodic command
Generate rich episodic summary for a completed task
Hybrid approach (D-023): Git owns timeline/metrics/artifacts,
task file owns AC + decisions, episodic merges both automatically.

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context-dispatcher](/docs/generated/context-dispatcher) | called-by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | called_by | Unit tests for context episodic (11 tests) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | tests_by | Unit tests for context episodic (11 tests) |
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | called_by | TODO: describe what this component does |
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | tests_by | TODO: describe what this component does |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-episodic.yaml`*
*Last verified: 2026-02-20*
